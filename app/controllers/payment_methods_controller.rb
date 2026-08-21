class PaymentMethodsController < ApplicationController
  before_action :set_payment_method, only: %i[edit update destroy]

  def index
    @payment_methods = Current.user.payment_methods.active.order(:id)
    @archived_payment_methods = Current.user.payment_methods.archived.order(:id)

    # 行ごとに件数を都度問い合わせないよう先読みする（N+1 回避）。
    # archivable? と同じく soft-delete 済みも含む全明細を数える（FK RESTRICT の実態に合わせる）。
    ids = @payment_methods.map(&:id)
    @transaction_counts = Current.user.transactions.where(payment_method_id: ids).group(:payment_method_id).count
    @import_payment_method_ids =
      Current.user.imports.where(payment_method_id: ids).distinct.pluck(:payment_method_id).to_set
  end

  def new
    @payment_method = Current.user.payment_methods.new
  end

  def create
    @payment_method = Current.user.payment_methods.new(payment_method_params)
    if @payment_method.save
      redirect_to payment_methods_path, notice: "支払方法を追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # アプリ層の uniqueness をすり抜けた同時送信の保険（DB の UNIQUE 制約が最後の砦）。
    @payment_method.errors.add(:name, :taken)
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    if @payment_method.update(payment_method_params)
      redirect_to payment_methods_path, notice: "支払方法を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @payment_method.errors.add(:name, :taken)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    # 現金（登録時に自動生成される特別枠）は削除不可。UI に削除ボタンを出さず、直接リクエストも拒否。
    return redirect_to payment_methods_path, alert: "現金は削除できません。" if @payment_method.cash?

    # 判定（archivable?）と削除/アーカイブを行ロックで原子的に行う。並行リクエストが間に
    # 明細/取り込みを追加しても、RESTRICT による FK 例外 500 にならないようにする。
    @archived = @payment_method.with_lock do
      if @payment_method.archivable?
        @payment_method.archive!
        true
      else
        @payment_method.destroy!
        false
      end
    end

    respond_to do |format|
      # 一覧をその場で更新する（削除は行除去、アーカイブは archived セクションへ移動）。
      format.turbo_stream
      # 非 Turbo は従来どおり全画面リダイレクト（Turbo もリダイレクトを追従するため後方互換）。
      format.html do
        notice = @archived ? "明細があるため支払方法をアーカイブしました。" : "支払方法を削除しました。"
        redirect_to payment_methods_path, notice: notice
      end
    end
  end

  private
    # 所有権スコープ: 他ユーザーの支払方法は見つからず 404（=操作不可）。
    def set_payment_method
      @payment_method = Current.user.payment_methods.find(params[:id])
    end

    def payment_method_params
      permitted = params.require(:payment_method).permit(:name, :payment_type)
      # 現金は「自動生成される単一の特別枠・削除不可・種別変更不可」。この不変条件を
      # ビューだけでなくサーバー側でも強制する（S3 が category_key を permit しないのと同じ思想）:
      # - 新規で payment_type=cash を送っても種別を落とす → presence 違反で作成させない
      # - 既存の現金レコードの種別は変更させない（名前のみ変更可）
      permitted = permitted.except(:payment_type) if permitted[:payment_type] == "cash" || @payment_method&.cash?
      permitted
    end
end
