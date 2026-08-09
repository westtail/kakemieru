require "rails_helper"

RSpec.describe "退会", type: :feature do
  it "現在のパスワードと確認文字列で退会でき、以後ログインできない" do
    user = create(:user, email_address: "bye@example.com")

    sign_in_as(user)
    visit "/account"
    click_link "退会手続きへ"
    expect(page).to have_current_path("/account/delete")

    fill_in "現在のパスワード", with: "password"
    fill_in "確認のため「退会する」と入力してください", with: "退会する"
    click_button "退会する"

    expect(page).to have_current_path("/sign_in")
    expect(User.exists?(email_address: "bye@example.com")).to be(false)

    # 退会後はログインできない（明示的に認証失敗する）
    sign_in_as(user, password: "password")
    expect(page).to have_current_path("/sign_in")
    expect(page).to have_content("正しくありません")
  end
end
