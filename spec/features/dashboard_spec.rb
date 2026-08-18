require "rails_helper"

RSpec.describe "ダッシュボード", type: :feature do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user) }
  let(:food) { create(:category, user: user, name: "食費") }

  before do
    # 当月（テスト実行時点）に明細を用意する。
    this_month = Date.current.beginning_of_month
    create(:transaction, user: user, payment_method: payment_method,
           amount: 5000, category: food, date: this_month + 5)
    create(:transaction, user: user, payment_method: payment_method,
           amount: 1200, category: nil, date: this_month + 6) # 未分類
    sign_in_as(user)
  end

  it "当月の支出合計・円グラフ・未分類バッジを表示する" do
    visit root_path

    expect(page).to have_content("¥6,200")               # 合計（fetch 完了後）
    expect(page).to have_css("canvas")                    # 円グラフ
    expect(page).to have_link("未分類 1件 ⚠️")           # 未分類バッジ（件数）
  end

  it "月を切り替えると合計と URL が更新される（ページ遷移なし）" do
    prev_month = (Date.current.beginning_of_month << 1)
    create(:transaction, user: user, payment_method: payment_method,
           amount: 300, category: food, date: prev_month + 3)

    visit root_path
    expect(page).to have_content("¥6,200")

    click_button "前の月"

    expect(page).to have_content("¥300")                  # 前月の合計に更新
    expect(page).to have_current_path("/?month=#{prev_month.strftime('%Y-%m')}")

    # ブラウザバックで当月の表示・URL に戻る（popstate 追従）
    page.go_back
    expect(page).to have_content("¥6,200")
    expect(page).to have_current_path("/?month=#{Date.current.strftime('%Y-%m')}")
  end

  it "未分類バッジのリンク先は当月の未分類フィルタ一覧" do
    visit root_path
    month = Date.current.strftime("%Y-%m")
    expect(page).to have_link("未分類 1件 ⚠️", href: "/transactions?month=#{month}&category=")
  end
end
