class HomeController < ApplicationController
  # ダッシュボード（ログイン後トップ）。Authentication concern の
  # before_action :require_authentication により未ログインは /sign_in へリダイレクトされる。
  def index
  end
end
