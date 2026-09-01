module Transactions
  # 当月支出と「直前 WINDOW ヶ月の平均」を比較する（前年同月比の代替）。当月合計は呼び出し側で
  # 算出済みの値を受け取り、基準（直近平均）だけをここで集計する。基準は直前 WINDOW ヶ月のうち
  # 「データのある月」の平均（空の月は分母に含めない・当月は含めない）。集計は effective_amount/
  # effective_date（DB 生成カラム）＋ not_deleted。
  # 戻り値: { window:, months:, baseline:, diff:, rate: }。diff は 当月 - 基準。rate（増減率%）は
  # 基準が 0（直近にデータ無し）のとき nil。
  class RecentAverageComparison
    WINDOW = 3

    def initialize(user:, month:, current_total:)
      @user = user
      @month = month.beginning_of_month
      @current_total = current_total
    end

    def call
      start = @month - WINDOW.months
      # [start, 当月初) の範囲＝直前 WINDOW ヶ月（当月は含めない）。月ごとに合計する。
      totals = @user.transactions.not_deleted
                    .where(effective_date: start...@month)
                    .group(Arel.sql("date_trunc('month', effective_date)::date"))
                    .sum(:effective_amount)

      months = totals.size
      baseline = months.zero? ? 0 : (totals.values.sum.to_f / months).round
      diff = @current_total - baseline
      # 基準が正のときだけ増減率を出す。0（返金相殺）や負（返金超過）は率が定義できないため nil。
      rate = baseline.positive? ? ((diff.to_f / baseline) * 100).round(1) : nil
      rate = 0.0 if rate&.zero? # -0.0 を 0.0 に正規化

      { window: WINDOW, months: months, baseline: baseline, diff: diff, rate: rate }
    end
  end
end
