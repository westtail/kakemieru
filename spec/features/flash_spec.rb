require "rails_helper"

# フラッシュメッセージの共通挙動（#52）。閉じるボタンで消せる（自動フェードは時間依存のため別）。
RSpec.describe "フラッシュメッセージ", type: :feature do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  it "アクションの通知が色付きで表示され、閉じるボタンで消せる" do
    visit new_category_path
    fill_in "カテゴリ名", with: "テストカテゴリ"
    click_button "追加"

    expect(page).to have_css(".flash-notice", text: "カテゴリを追加しました")

    within(".flash-notice") { click_button "閉じる" }

    expect(page).to have_no_css(".flash-notice")
  end
end
