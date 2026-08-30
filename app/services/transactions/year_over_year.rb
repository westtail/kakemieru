module Transactions
  # 当月支出と前年同月支出を比較する。当月合計は呼び出し側（サマリー）で算出済みの値を受け取り、
  # 前年同月だけをここで集計する（same-month の二重集計を避ける）。集計は effective_amount/
  # effective_date（DB 生成カラム）＋ not_deleted。戻り値: { previous_month:, previous_total:, diff:, rate: }。
  # diff は 当月 - 前年同月。rate（増減率%）は前年同月が 0 のとき nil（表示側で「新規」等に振る）。
  class YearOverYear
    def initialize(user:, month:, current_total:)
      @user = user
      @month = month.beginning_of_month
      @current_total = current_total
    end

    def call
      previous = @month.prev_year
      previous_total = @user.transactions.not_deleted.in_month(previous.year, previous.month).sum(:effective_amount)
      diff = @current_total - previous_total
      rate = previous_total.zero? ? nil : ((diff.to_f / previous_total) * 100).round(1)

      { previous_month: previous.strftime("%Y-%m"), previous_total: previous_total, diff: diff, rate: rate }
    end
  end
end
