# システム spec 用のログインヘルパー。
# 認証画面（/sign_in）は #18 で実装予定。実際に使われるのは #54（認証フロー E2E）以降。
# メソッド定義のみのため、ルート未実装でも読み込み時にエラーにはならない。
module AuthenticationHelper
  # 指定ユーザーでログイン画面からサインインする。
  def sign_in_as(user, password: "password")
    visit "/sign_in"
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: password
    click_button "ログイン"
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :feature
end
