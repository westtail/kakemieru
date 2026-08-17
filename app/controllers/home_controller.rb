class HomeController < ApplicationController
  include MonthParam

  # ダッシュボード（ログイン後トップ）。Authentication concern の
  # before_action :require_authentication により未ログインは /sign_in へリダイレクトされる。
  def index
    # 初期表示月。URL の ?month=YYYY-MM を検証し、不正・欠落は当月にフォールバックする。
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
  end
end
