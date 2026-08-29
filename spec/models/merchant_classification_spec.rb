require "rails_helper"

RSpec.describe MerchantClassification, type: :model do
  let(:user) { create(:user) }
  let(:food) { create(:category, user: user, name: "食費") }

  it "factory が有効" do
    expect(build(:merchant_classification)).to be_valid
  end

  it { is_expected.to validate_presence_of(:merchant_name) }

  it "merchant_name は user ごとに一意（別ユーザーは同名可）" do
    create(:merchant_classification, user: user, category: food, merchant_name: "Amazon")

    dup = build(:merchant_classification, user: user, category: food, merchant_name: "Amazon")
    expect(dup).not_to be_valid

    other = create(:user)
    other_cat = create(:category, user: other, name: "食費")
    expect(build(:merchant_classification, user: other, category: other_cat, merchant_name: "Amazon")).to be_valid
  end

  it "他ユーザーの category は紐づけられない（テナント整合）" do
    other = create(:user)
    others_category = create(:category, user: other, name: "他人")
    record = build(:merchant_classification, user: user, category: others_category)
    expect(record).not_to be_valid
    expect(record.errors[:category]).to be_present
  end

  it "merchant_name は正規化して保存する（NFKC + 前後空白除去 + 小文字化）" do
    record = create(:merchant_classification, user: user, category: food, merchant_name: " Ｌａｗｓｏｎ ")
    expect(record.merchant_name).to eq("lawson")
  end
end
