class HomeController < ApplicationController
  # 認証画面（ログイン）は #18 で実装予定。それまでトップ画面は公開のままにし、
  # generator が追加した全画面認証必須（Authentication concern）で既存の
  # トップ表示が塞がれないようにする。保護ポリシーの確定は #18 で行う。
  allow_unauthenticated_access only: :index

  def index
  end
end
