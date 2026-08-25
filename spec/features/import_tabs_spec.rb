require "rails_helper"

# 取り込み画面の CSV / 手動 タブ切替（#52）。選んだ方だけ表示する。
RSpec.describe "取り込みのタブ切替", type: :feature do
  let(:user) { create(:user) }

  before do
    create(:payment_method, user: user, name: "楽天カード")
    sign_in_as(user)
  end

  it "初期は CSV タブが表示され、手動フォームは隠れている" do
    visit new_import_path

    expect(page).to have_field("CSVファイル（楽天カード・Shift-JIS）")
    expect(page).to have_no_button("行を追加") # 手動パネルは非表示
  end

  it "手動タブをクリックすると手動フォームに切り替わり、CSV は隠れる" do
    visit new_import_path
    click_button "手動でまとめて入力"

    expect(page).to have_button("行を追加")
    expect(page).to have_no_field("CSVファイル（楽天カード・Shift-JIS）") # CSV パネルは非表示
  end

  it "手動リンクの hash 付き URL で開くと手動タブが初期表示される" do
    visit new_import_path(anchor: "manual-import")

    expect(page).to have_button("行を追加")
    expect(page).to have_no_field("CSVファイル（楽天カード・Shift-JIS）")
  end
end
