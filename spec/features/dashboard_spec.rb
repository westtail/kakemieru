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

  it "当月の支出合計・円グラフ・月別推移・未分類バッジを表示する" do
    visit root_path

    expect(page).to have_content("¥6,200")                # 合計（fetch 完了後）
    expect(page).to have_content("月別の支出推移")         # 推移セクション（#153）
    expect(page).to have_css('canvas[aria-label="カテゴリ別支出の円グラフ"]')
    expect(page).to have_css('canvas[aria-label="月別支出の棒グラフ"]') # 推移の棒グラフ
    expect(page).to have_link("未分類 1件 ⚠️")            # 未分類バッジ（件数）
  end

  it "前年同月比を表示する（前年同月にデータがある場合）" do
    last_year = Date.current.beginning_of_month.prev_year
    create(:transaction, user: user, payment_method: payment_method,
           amount: 3100, category: food, date: last_year + 3)

    visit root_path

    # 当月 6,200 vs 前年同月 3,100 → +100.0%（+¥3,100）
    expect(page).to have_content("前年同月比 +100.0%（+¥3,100）")
  end

  it "月別推移を Chart.js の棒グラフとして6ヶ月分描画する" do
    visit root_path
    expect(page).to have_content("¥6,200") # fetch→描画の完了を待つ

    # canvas の有無だけでなく Chart.js インスタンスを取得して実描画を検証する。
    # importmap の "chart.js" を動的 import し（controller と同一モジュール）、canvas から Chart を引く。
    chart = page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      import("chart.js").then(({ Chart }) => {
        const canvas = document.querySelector('canvas[aria-label="月別支出の棒グラフ"]')
        const instance = Chart.getChart(canvas)
        done(instance ? { type: instance.config.type, points: instance.data.datasets[0].data.length } : null)
      }).catch(() => done(null))
    JS

    expect(chart).not_to be_nil                # Chart.js が生成されている
    expect(chart["type"]).to eq("bar")         # 棒グラフ
    expect(chart["points"]).to eq(6)           # 直近6ヶ月分（0埋め含む）
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
