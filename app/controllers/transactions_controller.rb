class TransactionsController < ApplicationController
  def index
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
    # 配列/ハッシュ型の細工パラメータでも 500 にせず「すべて」に倒す。
    @category = params[:category].is_a?(String) ? params[:category] : nil
    @keyword = params[:q].to_s.strip
    @categories = Current.user.categories.order(:id)
    @month_options = month_options

    scope = Current.user.transactions.not_deleted
                   .includes(:category, :payment_method)
                   .in_month(@month.year, @month.month)
    scope = apply_category_filter(scope, @category)
    scope = scope.merchant_prefix(@keyword) if @keyword.present?
    @transactions = scope.order(effective_date: :desc, id: :desc)
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
      # 文字列以外（配列/ハッシュ）や空は当月扱い（呼び出し側でフォールバック）。
      return nil unless value.is_a?(String) && value.present?

      Date.strptime(value, "%Y-%m")
    rescue ArgumentError
      nil
    end

    # カテゴリ絞り込み。nil/"all"=すべて、""=未分類、それ以外=その category_id。
    # scope は Current.user.transactions 配下なので、他人の id を渡しても 0 件になる。
    def apply_category_filter(scope, value)
      case value
      when nil, "all" then scope
      when "" then scope.where(category_id: nil)
      else scope.where(category_id: value)
      end
    end

    # 月セレクトの選択肢。明細が存在する月＋当月＋表示中の月を降順で。
    def month_options
      months = Current.user.transactions.not_deleted
                      .reorder(nil).distinct
                      .pluck(Arel.sql("date_trunc('month', effective_date)::date"))
      (months + [ @month, Date.current.beginning_of_month ]).uniq.sort.reverse
    end
end
