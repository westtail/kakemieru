require "rails_helper"

RSpec.describe "パスワードリセット", type: :feature do
  it "申請メールのリンクから再設定し、新しいパスワードでログインできる" do
    user = create(:user, email_address: "reset@example.com", password: "oldpassword")

    # 申請フォーム
    visit "/passwords/new"
    fill_in "メールアドレス", with: "reset@example.com"
    click_button "再設定メールを送信"
    expect(page).to have_current_path("/sign_in")

    # 送信されたメール本文から再設定リンクのパスを取り出す（:inline 配信）
    mail = ActionMailer::Base.deliveries.last
    expect(mail).to be_present
    body = (mail.text_part || mail).body.decoded
    reset_path = body[%r{/passwords/[^/\s]+/edit}] or raise "リセットリンクがメール本文に見つかりません"

    # 再設定
    visit reset_path
    fill_in "新しいパスワード", with: "brandnewpass", exact: true
    fill_in "新しいパスワード（確認）", with: "brandnewpass"
    click_button "パスワードを更新"
    expect(page).to have_current_path("/sign_in")

    # 新しいパスワードでログインできる
    sign_in_as(user, password: "brandnewpass")
    expect(page).to have_current_path("/")
  end
end
