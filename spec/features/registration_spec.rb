require "rails_helper"

RSpec.describe "サインアップ", type: :feature do
  it "登録するとそのままログインしてダッシュボードに入れる" do
    visit "/sign_up"
    fill_in "メールアドレス", with: "newbie@example.com"
    fill_in "パスワード", with: "password123", exact: true
    fill_in "パスワード（確認）", with: "password123"
    click_button "登録"

    expect(page).to have_current_path("/")
    expect(page).to have_content("掛け見える")
  end

  it "サーバ側バリデーションエラーではメッセージが表示され登録されない" do
    # HTML5 検証を通過させ、サーバ側の最小長(8)で落とす（短いパスワード）。
    visit "/sign_up"
    fill_in "メールアドレス", with: "shortpw@example.com"
    fill_in "パスワード", with: "short12", exact: true
    fill_in "パスワード（確認）", with: "short12"
    click_button "登録"

    expect(page).to have_css(".error-messages")
    expect(User.exists?(email_address: "shortpw@example.com")).to be(false)
  end
end
