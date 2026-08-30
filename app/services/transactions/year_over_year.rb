module Transactions
  # 当月支出と前年同月支出を比較する。集計は effective_amount/effective_date（DB 生成カラム）
  # ＋ not_deleted。戻り値: { previous_month:, previous_total:, diff:, rate: }。
  # diff は 当月 - 前年同月。rate（増減率%）は前年同月が 0 のとき nil（表示側で「新規」等に振る）。
  class YearOverYear
    def initialize(user:, month:)
      @user = user
      @month = month
    end

    def call
      previous = @month.prev_year
      previous_total = month_total(previous)
      diff = month_total(@month) - previous_total
      rate = previous_total.zero? ? nil : ((diff.to_f / previous_total) * 100).round(1)

      { previous_month: previous.strftime("%Y-%m"), previous_total: previous_total, diff: diff, rate: rate }
    end

    private
      def month_total(month)
        @user.transactions.not_deleted.in_month(month.year, month.month).sum(:effective_amount)
      end
  end
end
