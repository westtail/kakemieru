module Transactions
  # 指定月を末尾に、直近 count ヶ月の月別支出合計を返す（ダッシュボードの推移グラフ用）。
  # 集計は effective_amount + not_deleted。データの無い月は 0 で埋め、古い順で返す。
  # 戻り値: [{ month: "YYYY-MM", total: 整数 }, ...]
  class MonthlyTotals
    def initialize(user:, month:, count: 6)
      @user = user
      @month = month.beginning_of_month
      @count = count
    end

    def call
      start = @month - (@count - 1).months
      sums = @user.transactions.not_deleted
                  .where(effective_date: start...@month.next_month)
                  .group(Arel.sql("date_trunc('month', effective_date)::date"))
                  .sum(:effective_amount)
      by_month = sums.transform_keys { |date| date.strftime("%Y-%m") }

      (0...@count).map do |offset|
        key = (start + offset.months).strftime("%Y-%m")
        { month: key, total: by_month[key] || 0 }
      end
    end
  end
end
