require "rails_helper"

RSpec.describe CategoryClassifier do
  let(:user) { create(:user) }
  let(:food) { create(:category, user: user, name: "食費") }

  it "マッピングが無ければ nil（未分類）" do
    expect(CategoryClassifier.category_id_for(user, "ローソン")).to be_nil
  end

  it "一致すれば紐づく category_id を返す" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
    expect(CategoryClassifier.category_id_for(user, "ローソン")).to eq(food.id)
  end

  it "merchant_name を正規化して照合する（全角/前後空白/大文字小文字違いを吸収）" do
    create(:merchant_classification, user: user, category: food, merchant_name: "Amazon")

    expect(CategoryClassifier.category_id_for(user, " Ａｍａｚｏｎ ")).to eq(food.id)
    expect(CategoryClassifier.category_id_for(user, "amazon")).to eq(food.id)
    expect(CategoryClassifier.category_id_for(user, "AMAZON")).to eq(food.id)
  end

  it "他ユーザーのマッピングは適用されない（テナント分離）" do
    other = create(:user)
    other_food = create(:category, user: other, name: "食費")
    create(:merchant_classification, user: other, category: other_food, merchant_name: "ローソン")

    expect(CategoryClassifier.category_id_for(user, "ローソン")).to be_nil
  end

  it "複数店舗をまとめて解決する（該当なしはキーに含めない）" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")

    result = CategoryClassifier.category_ids_for(user, [ "ローソン", "未登録店" ])
    expect(result).to eq({ "ローソン" => food.id })
  end

  it "merchant_name が空なら nil" do
    expect(CategoryClassifier.category_id_for(user, nil)).to be_nil
    expect(CategoryClassifier.category_id_for(user, "   ")).to be_nil
  end
end
