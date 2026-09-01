require "rails_helper"

# カテゴリの一括適用（#149）。複数行を選択して1カテゴリをまとめて設定する。
RSpec.describe "カテゴリの一括適用", type: :feature do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }
  let!(:food) { create(:category, user: user, name: "食費") }

  before do
    create(:transaction, user: user, payment_method: payment_method, category: nil,
           merchant_name: "コンビニA", date: Date.new(2026, 1, 10))
    create(:transaction, user: user, payment_method: payment_method, category: nil,
           merchant_name: "コンビニB", date: Date.new(2026, 1, 11))
    create(:transaction, user: user, payment_method: payment_method, category: nil,
           merchant_name: "残す明細", date: Date.new(2026, 1, 12))
    sign_in_as(user)
    visit transactions_path(month: "2026-01")
  end

  it "選択した明細だけにカテゴリを一括適用できる" do
    # 適用ボタンは初期は無効。
    expect(page).to have_button("選択した明細に一括適用", disabled: true)

    within("tr", text: "コンビニA") { check "選択" }
    within("tr", text: "コンビニB") { check "選択" }

    expect(page).to have_text("2 件選択中")
    select "食費", from: "category_id"
    click_button "選択した明細に一括適用"

    expect(page).to have_text("2件のカテゴリを変更しました")
    within("tr", text: "コンビニA") { expect(page).to have_select("カテゴリ", selected: "食費") }
    within("tr", text: "コンビニB") { expect(page).to have_select("カテゴリ", selected: "食費") }
    within("tr", text: "残す明細") { expect(page).to have_select("カテゴリ", selected: "未分類") }
  end

  it "全選択で全明細をまとめて設定できる" do
    check "全選択"
    expect(page).to have_text("3 件選択中")

    select "食費", from: "category_id"
    click_button "選択した明細に一括適用"

    expect(page).to have_text("3件のカテゴリを変更しました")
  end

  it "選択中の行をインライン変更しても選択が保持される（Turbo 差し替え後の復元）" do
    within("tr", text: "コンビニA") { check "選択" }
    expect(page).to have_text("1 件選択中")

    # 行のカテゴリをインライン変更 → その行が Turbo Stream で差し替わる。
    within("tr", text: "コンビニA") { select "食費", from: "カテゴリ" }

    expect(page).to have_text("1 件選択中")
    within("tr", text: "コンビニA") { expect(page).to have_checked_field("選択") }
  end

  it "選択中の行を削除すると選択件数が減る" do
    within("tr", text: "コンビニA") { check "選択" }
    within("tr", text: "コンビニB") { check "選択" }
    expect(page).to have_text("2 件選択中")

    within("tr", text: "コンビニB") do
      click_button "削除"
      click_button "確定"
    end

    expect(page).to have_no_content("コンビニB")
    expect(page).to have_text("1 件選択中")
  end
end
