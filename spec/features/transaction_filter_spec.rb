require "rails_helper"

# #56: 明細一覧・絞り込みフローの E2E。月/カテゴリ/キーワードの GET 絞り込みを検証する。
RSpec.describe "明細一覧・絞り込み", type: :feature do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }
  let!(:food) { create(:category, user: user, name: "食費") }
  let!(:transit) { create(:category, user: user, name: "交通費") }

  before do
    # 1月: 食費(コンビニ) と 交通費(バス)。2月: 食費(カフェ)。
    create(:transaction, user: user, payment_method: payment_method,
           date: Date.new(2026, 1, 15), merchant_name: "コンビニ", category: food)
    create(:transaction, user: user, payment_method: payment_method,
           date: Date.new(2026, 1, 20), merchant_name: "バス", category: transit)
    create(:transaction, user: user, payment_method: payment_method,
           date: Date.new(2026, 2, 5), merchant_name: "カフェ", category: food)
    sign_in_as(user)
  end

  it "指定した月の明細だけが一覧に表示される" do
    visit transactions_path(month: "2026-01")

    expect(page).to have_content("コンビニ")
    expect(page).to have_content("バス")
    expect(page).to have_no_content("カフェ")
  end

  it "月セレクトで絞り込むとその月の明細に切り替わる" do
    visit transactions_path(month: "2026-01")
    expect(page).to have_content("コンビニ")

    select "2026年2月", from: "月"
    click_button "絞り込む"

    expect(page).to have_content("カフェ")
    expect(page).to have_no_content("コンビニ")
  end

  it "カテゴリセレクトで絞り込むとそのカテゴリの明細だけになる" do
    visit transactions_path(month: "2026-01")

    # 絞り込みバーのカテゴリ（行内のカテゴリ変更 select と区別するため id で指定）。
    select "交通費", from: "category"
    click_button "絞り込む"

    expect(page).to have_content("バス")
    expect(page).to have_no_content("コンビニ")
  end

  it "キーワードで店舗名を前方一致検索できる" do
    visit transactions_path(month: "2026-01")

    fill_in "キーワード", with: "コンビニ"
    click_button "絞り込む"

    expect(page).to have_content("コンビニ")
    expect(page).to have_no_content("バス")
  end
end
