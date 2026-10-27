require "rails_helper"

RSpec.describe "ランディングページ", type: :feature do
  it "未ログインで / を訪れるとLPが表示され、新規登録へ遷移できる" do
    visit "/"

    expect(page).to have_content("見える化")
    expect(page).to have_link("ログイン", href: new_session_path)

    first(:link, "無料で始める").click
    expect(page).to have_current_path(new_registration_path)
  end

  it "ヘッダーのログインからログイン画面へ遷移する" do
    visit "/"
    within("header") { click_link "ログイン" }
    expect(page).to have_current_path(new_session_path)
  end

  it "ヘッダーの新規登録から登録画面へ遷移する" do
    visit "/"
    within("header") { click_link "新規登録" }
    expect(page).to have_current_path(new_registration_path)
  end

  it "未ログイン時はアプリ内ナビ（明細・カテゴリ）を表示しない" do
    visit "/"
    expect(page).not_to have_link("明細")
    expect(page).not_to have_link("カテゴリ")
  end
end
