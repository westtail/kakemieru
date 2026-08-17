require "rails_helper"

RSpec.describe "明細のカテゴリ即時変更・削除（Turbo Stream）", type: :feature do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }
  let!(:food) { create(:category, user: user, name: "食費") }

  before do
    create(:transaction, user: user, payment_method: payment_method,
           date: Date.new(2026, 1, 15), merchant_name: "コンビニ", category: nil)
    sign_in_as(user)
    visit transactions_path(month: "2026-01")
  end

  it "一覧のカテゴリを選ぶと即時に反映される（ページ遷移なし）" do
    within("tr", text: "コンビニ") do
      select "食費", from: "カテゴリ"
    end
    # Turbo Stream で行が差し替わり、選択が保持される
    expect(page).to have_current_path(transactions_path(month: "2026-01"))
    expect(user.transactions.first.reload.category).to eq(food)
    within("tr", text: "コンビニ") do
      expect(page).to have_select("カテゴリ", selected: "食費")
    end
  end

  it "削除ボタンで確認バナーが出て、確定すると行が消える" do
    within("tr", text: "コンビニ") { click_button "削除" }
    expect(page).to have_content("削除しますか？")

    within("tr", text: "コンビニ") { click_button "確定" }
    expect(page).to have_no_content("コンビニ")
    expect(user.transactions.first.reload.deleted_at).to be_present
  end

  it "確認バナーのキャンセルで削除されない" do
    within("tr", text: "コンビニ") { click_button "削除" }
    expect(page).to have_content("削除しますか？")

    within("tr", text: "コンビニ") { click_button "キャンセル" }
    within("tr", text: "コンビニ") do
      expect(page).to have_no_content("削除しますか？")
      expect(page).to have_button("削除")
    end
    expect(user.transactions.first.reload.deleted_at).to be_nil
  end
end
