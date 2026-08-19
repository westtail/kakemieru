class ImportsController < ApplicationController
  before_action :set_import, only: %i[show cancel_confirm cancel]

  def index
    @imports = Current.user.imports.includes(:payment_method).order(created_at: :desc)
    # 各 Import の未削除件数を1クエリで取得（取消済/一部取消の判定・N+1 回避）。
    @active_counts = Current.user.transactions.not_deleted
                            .where(import_id: @imports.ids).group(:import_id).count
  end

  # 取り込み詳細。含まれる明細（取消済みも含む）を表示する。
  def show
    # 支払方法は @import から表示するため、行ごとに使う category のみ eager load する。
    @transactions = @import.transactions.includes(:category)
                           .order(effective_date: :desc, id: :desc)
    @active_count = @import.transactions.not_deleted.count
  end

  def new
    set_form_collections
    @manual_rows = [ {} ] # 手動入力の初期行（空1行）
  end

  # CSV 取り込み
  def create
    payment_method = Current.user.payment_methods.active.find(params.dig(:import, :payment_method_id))

    result = Imports::CsvImporter.new(
      user: Current.user,
      payment_method: payment_method,
      uploaded_file: params.dig(:import, :file)
    ).call

    if result.errors.empty?
      redirect_to transactions_path(month: redirect_month(result.import)),
                  notice: "#{result.import.row_count}件を取り込みました。"
    else
      rerender_new(result.errors)
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to new_import_path, alert: "支払方法を選択してください。"
  end

  # 手動まとめ入力
  def create_manual
    default = Current.user.payment_methods.active.find(manual_params[:payment_method_id])
    rows = manual_params[:transactions] || []

    result = Imports::ManualBulkImporter.new(
      user: Current.user,
      default_payment_method: default,
      rows: rows
    ).call

    if result.errors.empty?
      redirect_to transactions_path(month: redirect_month(result.import)),
                  notice: "#{result.import.row_count}件を保存しました。"
    else
      rerender_new(result.errors, manual_rows: rows.presence || [ {} ])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to new_import_path, alert: "支払方法を選択してください。"
  end

  # 取り込み取り消しの確認画面。件数と警告を表示する。
  def cancel_confirm
    @active_count = @import.transactions.not_deleted.count
  end

  # 取り込み取り消しの実行。紐づく明細を一括ソフト削除する。Import レコードは残す
  # （file_hash を温存し、同ファイルの再取り込みは引き続きエラーにする）。
  def cancel
    count = @import.transactions.not_deleted.update_all(deleted_at: Time.current)
    if count.zero?
      redirect_to imports_path, alert: "取り消せる明細はありませんでした。"
    else
      redirect_to imports_path, notice: "#{count}件の明細を取り消しました。"
    end
  end

  private
    # 所有権スコープ: 他ユーザーの取り込みは見つからず 404。
    def set_import
      @import = Current.user.imports.find(params[:id])
    end

    def manual_params
      params.require(:manual).permit(
        :payment_method_id,
        transactions: %i[date merchant_name amount category_id payment_method_id]
      )
    end

    def set_form_collections
      @payment_methods = Current.user.payment_methods.active.order(:id)
      @categories = Current.user.categories.order(:id)
    end

    def rerender_new(errors, manual_rows: [ {} ])
      @errors = errors
      @manual_rows = manual_rows
      set_form_collections
      render :new, status: :unprocessable_entity
    end

    # 取り込んだ明細の最新月へ誘導する（結果が見える）。
    def redirect_month(import)
      import.transactions.maximum(:effective_date)&.strftime("%Y-%m")
    end
end
