class TransactionsController < ApplicationController
  def index
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
    @transactions = Current.user.transactions.not_deleted
                           .includes(:category, :payment_method)
                           .in_month(@month.year, @month.month)
                           .order(effective_date: :desc, id: :desc)
  end

  def new
    @transaction = Current.user.transactions.new(date: Date.current)
  end

  def create
    # import_id は付けない（手動1件入力 = NULL）。user は Current.user に固定。
    @transaction = Current.user.transactions.new(transaction_params)
    if @transaction.save
      redirect_to transactions_path(month: @transaction.effective_date.strftime("%Y-%m")),
                  notice: "明細を追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # 他ユーザーの category/payment_method を注入させない（user_id/override/effective_* も不可）。
    # 値の所有者チェックはモデルのテナント整合バリデーションで担保する。
    def transaction_params
      params.require(:transaction).permit(:date, :amount, :merchant_name, :category_id, :payment_method_id)
    end

    def parse_month(value)
      return nil if value.blank?

      Date.strptime(value, "%Y-%m")
    rescue ArgumentError
      nil
    end
end
