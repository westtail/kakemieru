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

  describe ".learn" do
    it "正規化した店舗名で category を user_manual として記録する" do
      MerchantClassification.learn(user: user, merchant_name: " Ｌａｗｓｏｎ ", category_id: food.id)

      record = user.merchant_classifications.sole
      expect(record.merchant_name).to eq("lawson") # 正規化
      expect(record.category_id).to eq(food.id)
      expect(record.source).to eq("user_manual")
      expect(record.classified_at).to be_present
    end

    it "同じ店舗を再学習すると上書きする（最新の手動分類を優先）" do
      transport = create(:category, user: user, name: "交通費")
      MerchantClassification.learn(user: user, merchant_name: "ローソン", category_id: food.id)
      MerchantClassification.learn(user: user, merchant_name: "ローソン", category_id: transport.id)

      expect(user.merchant_classifications.count).to eq(1)
      expect(user.merchant_classifications.sole.category_id).to eq(transport.id)
    end

    it "店舗名や category が空なら何もしない" do
      expect { MerchantClassification.learn(user: user, merchant_name: "  ", category_id: food.id) }
        .not_to change(MerchantClassification, :count)
      expect { MerchantClassification.learn(user: user, merchant_name: "X", category_id: nil) }
        .not_to change(MerchantClassification, :count)
    end
  end

  describe ".forget" do
    it "その店舗のマッピングを削除する" do
      MerchantClassification.learn(user: user, merchant_name: "ローソン", category_id: food.id)
      expect { MerchantClassification.forget(user: user, merchant_name: "ローソン") }
        .to change { user.merchant_classifications.count }.from(1).to(0)
    end

    it "他ユーザーのマッピングは消さない" do
      other = create(:user)
      other_cat = create(:category, user: other, name: "食費")
      MerchantClassification.learn(user: user, merchant_name: "ローソン", category_id: food.id)
      MerchantClassification.learn(user: other, merchant_name: "ローソン", category_id: other_cat.id)

      MerchantClassification.forget(user: user, merchant_name: "ローソン")
      expect(other.merchant_classifications.count).to eq(1)
    end
  end
end
