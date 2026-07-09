require "rails_helper"

# E2E パイプライン（Capybara → Chrome コンテナ → web → レスポンス）の疎通確認。
# 認証実装前でも通せるよう、既存のトップ画面を実ブラウザで開いて検証する。
RSpec.describe "Smoke", type: :feature do
  it "トップ画面を実ブラウザで表示できる" do
    visit "/"
    expect(page).to have_content("掛け見える")
  end
end
