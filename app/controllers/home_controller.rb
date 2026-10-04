class HomeController < ApplicationController
  include MonthParam

  allow_unauthenticated_access only: :index

  # 未ログインは公開ランディングページ、ログイン済はダッシュボード（同一 URL で出し分け）。
  def index
    return render "home/landing", layout: "landing" unless authenticated?

    # 初期表示月。URL の ?month=YYYY-MM を検証し、不正・欠落は当月にフォールバックする。
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
  end
end
