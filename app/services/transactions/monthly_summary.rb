module Transactions
  # 指定ユーザー・指定月の月次サマリーを返す。集計は effective_amount/effective_date
  # （DB 生成カラム）＋ not_deleted で行う。
  # 戻り値: { month: "YYYY-MM", total:, categories: [{ id:, name:, amount: }, ...] }
  class MonthlySummary
    def initialize(user:, month:)
      @user = user
      @month = month
    end

    def call
      scope = @user.transactions.not_deleted.in_month(@month.year, @month.month)
      names = @user.categories.pluck(:id, :name).to_h
      by_category = scope.group(:category_id).sum(:effective_amount) # { category_id|nil => amount }

      categories = by_category.map do |category_id, amount|
        # fetch のデフォルトで、names 取得後にカテゴリが増える稀なレースでも name が nil に
        # ならないようにする（sort_by で nil <=> String の 500 を防ぐ）。
        name = category_id ? names.fetch(category_id, "未分類") : "未分類"
        { id: category_id, name: name, amount: amount }
      end.sort_by { |category| [ -category[:amount], category[:name] ] }

      { month: @month.strftime("%Y-%m"), total: by_category.values.sum, categories: categories }
    end
  end
end
