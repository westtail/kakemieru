module Transactions
  # ダッシュボード用の月次サマリー JSON（GET 専用・読み取り専用）。
  # CSRF は null_session をこのコントローラに隔離する（書き込みを持つ TransactionsController には
  # 付けない）。認証は API 向けに 401 を返す（HTML のリダイレクトはしない）。
  class SummariesController < ApplicationController
    include MonthParam

    allow_unauthenticated_access only: :show
    protect_from_forgery with: :null_session
    before_action :require_json_session, only: :show

    def show
      month = parse_month(params[:month])
      return render json: { error: "月の形式が不正です（YYYY-MM）" }, status: :unprocessable_entity if month.nil?

      summary = MonthlySummary.new(user: Current.user, month: month).call
      # 直近6ヶ月の支出推移も同梱する（ダッシュボードの月別グラフ用）。
      summary[:monthly_totals] = MonthlyTotals.new(user: Current.user, month: month).call
      # 前年同月比（当月 vs 前年同月）も同梱する。
      summary[:year_over_year] = YearOverYear.new(user: Current.user, month: month).call
      render json: summary
    end

    private
      def require_json_session
        head :unauthorized unless resume_session
      end
  end
end
