require "rails_helper"

RSpec.describe "取り込みドロップダウン", type: :feature do
  it "クリックで開き、項目が表示される" do
    user = create(:user)
    sign_in_as(user)

    # 初期はメニューが閉じている（項目は非表示）
    expect(page).to have_no_link("取り込み履歴")

    click_button "取り込み"

    # 開くと3項目が表示される
    expect(page).to have_link("CSVから取り込む")
    expect(page).to have_link("手動でまとめて入力")
    expect(page).to have_link("取り込み履歴")
  end

  it "外側をクリックすると閉じる" do
    user = create(:user)
    sign_in_as(user)

    click_button "取り込み"
    expect(page).to have_link("取り込み履歴")

    # メニュー外（見出し）をクリックすると閉じる
    find("h1").click
    expect(page).to have_no_link("取り込み履歴")
  end
end
