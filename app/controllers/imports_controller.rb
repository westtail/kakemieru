class ImportsController < ApplicationController
  def index
    @imports = Current.user.imports.includes(:payment_method).order(created_at: :desc)
  end

  def new
    @payment_methods = Current.user.payment_methods.active.order(:id)
  end

  def create
    # 支払方法は本人のアクティブなものだけ（所有権スコープ・生 params を Import に渡さない）。
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
      @errors = result.errors
      @payment_methods = Current.user.payment_methods.active.order(:id)
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to new_import_path, alert: "支払方法を選択してください。"
  end

  private
    # 取り込んだ明細の最新月へ誘導する（結果が見える）。
    def redirect_month(import)
      import.transactions.maximum(:effective_date)&.strftime("%Y-%m")
    end
end
