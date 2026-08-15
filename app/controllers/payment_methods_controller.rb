class PaymentMethodsController < ApplicationController
  before_action :set_payment_method, only: %i[edit update destroy]

  def index
    # S4 は全件アクティブ（アーカイブ運用は S7）。
    @payment_methods = Current.user.payment_methods.active.order(:id)
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
    if @payment_method.cash?
      redirect_to payment_methods_path, alert: "現金は削除できません。"
    elsif @payment_method.archivable?
      # 明細を持つ支払方法は物理削除せずアーカイブ（過去明細の参照・集計のため）。
      @payment_method.archive!
      redirect_to payment_methods_path, notice: "明細があるため支払方法をアーカイブしました。"
    else
      @payment_method.destroy
      redirect_to payment_methods_path, notice: "支払方法を削除しました。"
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
