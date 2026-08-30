require "rails_helper"

RSpec.describe MerchantRecommendations, type: :service do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user) }
  let(:food) { create(:category, user: user, name: "食費") }
  let(:transport) { create(:category, user: user, name: "交通費") }

  def tx(merchant:, category:, date: Date.new(2026, 1, 10))
    create(:transaction, user: user, payment_method: payment_method,
           merchant_name: merchant, category: category, date: date)
  end

  def call
    described_class.new(user: user).call
  end

  it "同じ店舗を2回以上同じカテゴリにした実績をおすすめに出す" do
    2.times { tx(merchant: "ローソン", category: food) }

    result = call
    expect(result.size).to eq(1)
    expect(result.first).to have_attributes(
      merchant_name: "ローソン", category_id: food.id, category_name: "食費", count: 2
    )
  end

  it "1回だけの店舗は出さない（ノイズ除去）" do
    tx(merchant: "たまたま", category: food)
    expect(call).to be_empty
  end

  it "登録済みの店舗ルールは除外する" do
    2.times { tx(merchant: "ローソン", category: food) }
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")

    expect(call).to be_empty
  end

  it "特別ルールを持つ店舗は除外する（被り対策・ADR-0048）" do
    2.times { tx(merchant: "楽天SP", category: food) }
    create(:special_rule, user: user, category: food, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200)

    expect(call).to be_empty
  end

  it "件数の多い順に並べる" do
    3.times { tx(merchant: "スタバ", category: food) }
    2.times { tx(merchant: "ローソン", category: food) }

    expect(call.map(&:merchant_name)).to eq(%w[スタバ ローソン])
  end

  it "表記ゆれ（大文字小文字・全角）は正規化して集約する" do
    tx(merchant: "Amazon", category: food)
    tx(merchant: "ＡＭＡＺＯＮ", category: food)

    result = call
    expect(result.size).to eq(1)
    expect(result.first.count).to eq(2)
  end

  it "最頻カテゴリを提示する（複数カテゴリで割れた場合）" do
    2.times { tx(merchant: "西友", category: food) }
    tx(merchant: "西友", category: transport)

    expect(call.first).to have_attributes(category_id: food.id, count: 2)
  end

  it "未分類の明細は集計しない" do
    2.times { tx(merchant: "未分類店", category: nil) }
    expect(call).to be_empty
  end

  it "取り消し済み（ソフトデリート）明細は集計しない" do
    2.times { tx(merchant: "ローソン", category: food).soft_delete! }
    expect(call).to be_empty
  end

  it "他ユーザーの明細は混ざらない（テナント）" do
    other = create(:user)
    other_pm = create(:payment_method, user: other)
    other_cat = create(:category, user: other, name: "食費")
    2.times do
      create(:transaction, user: other, payment_method: other_pm,
             merchant_name: "ローソン", category: other_cat, date: Date.new(2026, 1, 10))
    end

    expect(call).to be_empty
  end
end
