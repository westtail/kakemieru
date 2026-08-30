require "rails_helper"

RSpec.describe SpecialRule, type: :model do
  let(:user) { create(:user) }
  let(:food) { create(:category, user: user, name: "食費") }

  it "factory が有効" do
    expect(build(:special_rule)).to be_valid
  end

  it { is_expected.to validate_presence_of(:merchant_name) }
  it { is_expected.to validate_length_of(:merchant_name).is_at_most(255) }
  it { is_expected.to validate_length_of(:note).is_at_most(255) }

  it "merchant_name は正規化して保存する（NFKC + 前後空白除去 + 小文字化）" do
    record = create(:special_rule, user: user, category: food, merchant_name: " Ｒａｋｕｔｅｎ ")
    expect(record.merchant_name).to eq("rakuten")
  end

  it "他ユーザーの category は紐づけられない（テナント整合）" do
    other = create(:user)
    others_category = create(:category, user: other, name: "他人")
    record = build(:special_rule, user: user, category: others_category)
    expect(record).not_to be_valid
    expect(record.errors[:category]).to be_present
  end

  describe "条件の検証" do
    it "判別条件（金額・日）が1つも無ければ無効" do
      record = build(:special_rule, user: user, category: food, amount_min: nil, amount_max: nil, day_of_month: nil)
      expect(record).not_to be_valid
    end

    it "amount_max < amount_min は無効" do
      record = build(:special_rule, user: user, category: food, amount_min: 2000, amount_max: 1000)
      expect(record).not_to be_valid
      expect(record.errors[:amount_max]).to be_present
    end

    it "day_of_month は 1..31 の範囲" do
      expect(build(:special_rule, user: user, category: food, amount_min: nil, amount_max: nil, day_of_month: 0)).not_to be_valid
      expect(build(:special_rule, user: user, category: food, amount_min: nil, amount_max: nil, day_of_month: 32)).not_to be_valid
      expect(build(:special_rule, user: user, category: food, amount_min: nil, amount_max: nil, day_of_month: 15)).to be_valid
    end

    it "金額のみ・日のみ・両方いずれでも条件があれば有効" do
      expect(build(:special_rule, user: user, category: food, amount_min: 500, amount_max: 1500, day_of_month: nil)).to be_valid
      expect(build(:special_rule, user: user, category: food, amount_min: nil, amount_max: nil, day_of_month: 10)).to be_valid
    end
  end

  describe "#matches?" do
    it "金額範囲内・日一致で true、外れで false" do
      rule = build(:special_rule, amount_min: 1000, amount_max: 2000, day_of_month: 15)
      expect(rule.matches?(amount: 1500, day: 15)).to be(true)
      expect(rule.matches?(amount: 999, day: 15)).to be(false)  # 金額下限外
      expect(rule.matches?(amount: 2001, day: 15)).to be(false) # 金額上限外
      expect(rule.matches?(amount: 1500, day: 16)).to be(false) # 日不一致
    end

    it "完全一致（min=max）はその金額だけ一致" do
      rule = build(:special_rule, amount_min: 1200, amount_max: 1200, day_of_month: nil)
      expect(rule.matches?(amount: 1200, day: 1)).to be(true)
      expect(rule.matches?(amount: 1201, day: 1)).to be(false)
    end

    it "未設定の条件は評価しない（日のみ指定なら金額は不問）" do
      rule = build(:special_rule, amount_min: nil, amount_max: nil, day_of_month: 27)
      expect(rule.matches?(amount: 99_999, day: 27)).to be(true)
      expect(rule.matches?(amount: 99_999, day: 26)).to be(false)
    end
  end

  describe "#specificity と #amount_span（複数一致の優先用）" do
    it "条件数が多いほど specificity が大きい" do
      broad = build(:special_rule, amount_min: 1000, amount_max: 2000, day_of_month: nil)
      narrow = build(:special_rule, amount_min: 1000, amount_max: 2000, day_of_month: 15)
      expect(narrow.specificity).to be > broad.specificity
    end

    it "金額幅が狭いほど amount_span が小さい（両端未設定は無限大）" do
      exact = build(:special_rule, amount_min: 1200, amount_max: 1200)
      wide = build(:special_rule, amount_min: 1000, amount_max: 2000)
      open = build(:special_rule, amount_min: nil, amount_max: nil, day_of_month: 5)
      expect(exact.amount_span).to eq(0)
      expect(wide.amount_span).to eq(1000)
      expect(open.amount_span).to eq(Float::INFINITY)
    end
  end
end
