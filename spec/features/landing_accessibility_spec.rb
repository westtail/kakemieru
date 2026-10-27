require "rails_helper"

# ランディングページの基本的なアクセシビリティ項目を検証する。
# 注: 本プロジェクトのブラウザ駆動は Cuprite（Ferrum）で、axe-core-rspec（Selenium 前提）は
# 非互換のため導入していない。ここでは依存を増やさず、重要な観点を直接チェックする。
RSpec.describe "ランディングページ アクセシビリティ", type: :feature do
  before { visit "/" }

  it "ページ言語（lang=ja）が指定されている" do
    expect(page.find("html")[:lang]).to eq("ja")
  end

  it "見出しは h1 が1つだけ（見出し階層の起点が一意）" do
    expect(page).to have_css("h1", count: 1)
    expect(page).to have_css("h2")
  end

  it "情報を持つ図（ドーナツ）にはアクセシブルな名前がある" do
    expect(page).to have_css("svg[aria-label='カテゴリ別支出の円グラフ']")
  end

  it "装飾アイコンは支援技術から隠されている（aria-hidden）" do
    expect(page).to have_css("svg[aria-hidden='true']", minimum: 3)
  end

  it "すべてのリンクに識別可能なテキストがある（空リンクが無い）" do
    expect(page).to have_css("a")
    page.all("a", visible: :all).each do |link|
      accessible_name = link.text.strip
      accessible_name = link[:"aria-label"].to_s.strip if accessible_name.empty?
      expect(accessible_name).not_to be_empty
    end
  end
end
