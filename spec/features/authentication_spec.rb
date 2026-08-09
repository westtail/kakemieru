require "rails_helper"

RSpec.describe "認証フロー", type: :feature do
  it "ログイン → ダッシュボード表示 → ログアウトができる" do
    user = create(:user)

    sign_in_as(user)

    # ログイン成功でダッシュボード（ログイン後トップ）へ
    expect(page).to have_current_path("/")
    expect(page).to have_content("掛け見える")

    # ログアウトするとログイン画面へ戻る
    click_button "ログアウト"

    expect(page).to have_current_path("/sign_in")
    expect(page).to have_content("ログイン")
  end
end
