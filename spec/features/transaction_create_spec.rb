require "rails_helper"

# #56: 手動1件入力フローの E2E。新規フォームから保存し、一覧に反映されることを検証する。
RSpec.describe "明細の手動入力", type: :feature do
  let(:user) { create(:user) }
  let!(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }
  let!(:food) { create(:category, user: user, name: "食費") }

  before { sign_in_as(user) }

  it "フォームに入力して保存すると一覧に追加される" do
    visit new_transaction_path

    fill_in "利用日", with: "2026-01-20"
    fill_in "金額（円）", with: "1500"
    fill_in "店舗名", with: "商店街の八百屋"
    select "楽天カード", from: "支払方法"
    select "食費", from: "カテゴリ"
    click_button "追加"

    # 保存後は登録月の一覧へ遷移し、追加した明細が表示される。
    expect(page).to have_current_path(transactions_path(month: "2026-01"))
    expect(page).to have_content("明細を追加しました。")
    within("tr", text: "商店街の八百屋") do
      expect(page).to have_content("1,500")
      expect(page).to have_select("カテゴリ", selected: "食費")
    end
    expect(user.transactions.reload.count).to eq(1)
  end
end
