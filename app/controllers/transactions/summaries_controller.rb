module Transactions
  # ダッシュボード用の月次サマリー JSON（GET 専用・読み取り専用）。
  # CSRF は null_session をこのコントローラに隔離する（書き込みを持つ TransactionsController には
  # 付けない・#14）。認証は API 向けに 401 を返す（HTML のリダイレクトはしない）。
  class SummariesController < ApplicationController
    allow_unauthenticated_access only: :show
    protect_from_forgery with: :null_session
    before_action :require_json_session, only: :show

    def show
      month = parse_month
      return render json: { error: "月の形式が不正です（YYYY-MM）" }, status: :unprocessable_entity if month.nil?

      render json: MonthlySummary.new(user: Current.user, month: month).call
    end

    private
      def require_json_session
        head :unauthorized unless resume_session
      end

      def parse_month
        value = params[:month]
        # 厳密に YYYY-MM のみ許可する（strptime は末尾ゴミ "2026-04xx" を無視して通すため）。
        return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}\z/)

        Date.strptime(value, "%Y-%m")
      rescue ArgumentError
        nil
      end
  end
end
