module Transactions
  # 実データのある月数で割った月平均支出（全体・カテゴリ別）。明細ゼロの月は分母に含めない。
  # 分母は全体・カテゴリ別とも「明細のある月数」で共通。丸め前はカテゴリ別平均の合計＝全体平均だが、
  # 各値を四捨五入するため表示上はカテゴリ別の合計と全体が数円ずれ得る。
  # 集計は effective_amount/effective_date（DB 生成カラム）＋ not_deleted。
  # 戻り値: { months:, overall:, categories: [{ id:, name:, average: }, ...] }。
  class MonthlyAverage
    def initialize(user:)
      @user = user
    end

    def call
      scope = @user.transactions.not_deleted
      months = scope.distinct.count(Arel.sql("date_trunc('month', effective_date)::date"))
      return { months: 0, overall: 0, categories: [] } if months.zero?

      names = @user.categories.pluck(:id, :name).to_h
      by_category = scope.group(:category_id).sum(:effective_amount)
      total = by_category.values.sum

      categories = by_category.map do |category_id, amount|
        name = category_id ? names.fetch(category_id, "未分類") : "未分類"
        { id: category_id, name: name, average: (amount.to_f / months).round }
      end.sort_by { |category| [ -category[:average], category[:name] ] }

      { months: months, overall: (total.to_f / months).round, categories: categories }
    end
  end
end
