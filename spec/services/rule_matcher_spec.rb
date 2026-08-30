require "rails_helper"

RSpec.describe RuleMatcher, type: :service do
  let(:user) { create(:user) }
  let(:food) { create(:category, user: user, name: "食費") }
  let(:hobby) { create(:category, user: user, name: "娯楽") }

  def matcher(use_merchant: true, use_special: true)
    described_class.new(user: user, use_merchant: use_merchant, use_special: use_special)
  end

  def match(merchant:, amount:, day: 15, **opts)
    matcher(**opts).match(merchant_name: merchant, amount: amount, date: Date.new(2026, 1, day))
  end

  it "店舗ルールに一致すればそのカテゴリを返す（note は nil）" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
    result = match(merchant: "ローソン", amount: 500)
    expect(result.category_id).to eq(food.id)
    expect(result.note).to be_nil
  end

  it "どのルールにも一致しなければ nil" do
    expect(match(merchant: "無関係", amount: 500)).to be_nil
  end

  it "特別ルールは店舗ルールより優先される（金額一致時）" do
    create(:merchant_classification, user: user, category: food, merchant_name: "楽天SP")
    create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP",
           amount_min: 1200, amount_max: 1200, note: "Netflix")

    result = match(merchant: "楽天SP", amount: 1200)
    expect(result.category_id).to eq(hobby.id) # 特別優先
    expect(result.note).to eq("Netflix")
  end

  it "特別ルールが金額に一致しなければ店舗ルールへフォールバックする" do
    create(:merchant_classification, user: user, category: food, merchant_name: "楽天SP")
    create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP",
           amount_min: 1200, amount_max: 1200)

    result = match(merchant: "楽天SP", amount: 999) # 特別に外れる
    expect(result.category_id).to eq(food.id) # 店舗ルール
  end

  it "OR: 同一店舗の複数特別ルールがそれぞれの金額で当たる" do
    create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200, note: "Netflix")
    create(:special_rule, user: user, category: food, merchant_name: "楽天SP", amount_min: 500, amount_max: 500, note: "食材宅配")

    expect(match(merchant: "楽天SP", amount: 1200).note).to eq("Netflix")
    expect(match(merchant: "楽天SP", amount: 500).note).to eq("食材宅配")
  end

  it "複数一致は最も具体的なルールを選ぶ（条件数→金額幅→id）" do
    create(:special_rule, user: user, category: food, merchant_name: "楽天SP", amount_min: 1000, amount_max: 2000) # 広い
    narrow = create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP",
                    amount_min: 1000, amount_max: 2000, day_of_month: 15) # 条件多い

    result = match(merchant: "楽天SP", amount: 1500, day: 15)
    expect(result.category_id).to eq(hobby.id)
  end

  it "店舗名は正規化して照合する（大文字小文字・全角）" do
    create(:special_rule, user: user, category: hobby, merchant_name: "amazon", amount_min: 3000, amount_max: 3000, note: "Prime")
    expect(match(merchant: "ＡＭＡＺＯＮ", amount: 3000).note).to eq("Prime")
  end

  it "use_special:false なら特別ルールを無視する" do
    create(:merchant_classification, user: user, category: food, merchant_name: "楽天SP")
    create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200)

    result = match(merchant: "楽天SP", amount: 1200, use_special: false)
    expect(result.category_id).to eq(food.id) # 店舗ルールのみ
  end

  it "use_merchant:false なら店舗ルールを無視する" do
    create(:merchant_classification, user: user, category: food, merchant_name: "楽天SP")
    expect(match(merchant: "楽天SP", amount: 500, use_merchant: false)).to be_nil
  end

  it "他ユーザーのルールは混ざらない（テナント）" do
    other = create(:user)
    other_cat = create(:category, user: other, name: "食費")
    create(:merchant_classification, user: other, category: other_cat, merchant_name: "ローソン")
    expect(match(merchant: "ローソン", amount: 500)).to be_nil
  end
end
