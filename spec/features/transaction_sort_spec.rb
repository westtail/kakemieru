require "rails_helper"

# 明細一覧の列ソート（#147）。ヘッダークリックで並びが変わることを実ブラウザで確認する。
RSpec.describe "明細一覧の列ソート", type: :feature do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }

  before do
    create(:transaction, user: user, payment_method: payment_method,
           date: Date.new(2026, 1, 20), merchant_name: "Cショップ", amount: 100)
    create(:transaction, user: user, payment_method: payment_method,
           date: Date.new(2026, 1, 10), merchant_name: "Aショップ", amount: 300)
    sign_in_as(user)
    visit transactions_path(month: "2026-01")
  end

  # 先頭行の店舗名セル（2列目）。Capybara の待機付きマッチャで遷移完了まで待てる。
  FIRST_ROW_MERCHANT = "tbody#transactions tr:first-child td:nth-child(2)".freeze

  it "店舗名ヘッダーをクリックすると昇順に並び替わる" do
    # 既定は日付降順: 先頭は Cショップ(1/20)。
    expect(page).to have_css(FIRST_ROW_MERCHANT, text: "Cショップ")

    click_link "店舗名で並べ替え"

    # 店舗名昇順: 先頭が Aショップ になる（遷移完了まで待機）。
    expect(page).to have_css(FIRST_ROW_MERCHANT, text: "Aショップ")
  end
end
