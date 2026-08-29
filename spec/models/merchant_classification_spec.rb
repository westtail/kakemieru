require "rails_helper"

RSpec.describe MerchantClassification, type: :model do
  let(:user) { create(:user) }
  let(:food) { create(:category, user: user, name: "食費") }

  it "factory が有効" do
    expect(build(:merchant_classification)).to be_valid
  end

  it { is_expected.to validate_presence_of(:merchant_name) }
  it { is_expected.to validate_presence_of(:source) }
  it { is_expected.to validate_inclusion_of(:source).in_array(%w[ai user_manual]) }

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

  describe ".learn_all" do
    it "正規化＆重複除去した店舗名で category を user_manual として一括記録する" do
      MerchantClassification.learn_all(user: user, merchant_names: [ " Ｌａｗｓｏｎ ", "lawson", "Amazon" ], category_id: food.id)

      expect(user.merchant_classifications.pluck(:merchant_name)).to match_array(%w[lawson amazon]) # 重複は1件
      record = user.merchant_classifications.find_by(merchant_name: "lawson")
      expect(record.category_id).to eq(food.id)
      expect(record.source).to eq("user_manual")
      expect(record.classified_at).to be_present
    end

    it "同じ店舗を再学習すると上書きする（最新の手動分類を優先）" do
      transport = create(:category, user: user, name: "交通費")
      MerchantClassification.learn_all(user: user, merchant_names: [ "ローソン" ], category_id: food.id)
      MerchantClassification.learn_all(user: user, merchant_names: [ "ローソン" ], category_id: transport.id)

      expect(user.merchant_classifications.count).to eq(1)
      expect(user.merchant_classifications.sole.category_id).to eq(transport.id)
    end

    it "category_id 空や有効な店舗名が無ければ何もしない" do
      expect { MerchantClassification.learn_all(user: user, merchant_names: [ "X" ], category_id: nil) }
        .not_to change(MerchantClassification, :count)
      expect { MerchantClassification.learn_all(user: user, merchant_names: [ "  ", "" ], category_id: food.id) }
        .not_to change(MerchantClassification, :count)
    end
  end
end
