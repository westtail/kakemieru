require "rails_helper"

RSpec.describe CategoryClassifier do
  let(:user) { create(:user) }

  it "merchant_classifications が空なら nil（未分類）" do
    expect(CategoryClassifier.category_id_for(user, "ローソン")).to be_nil
  end

  it "一致すれば user の同 category_key のカテゴリ id を返す" do
    create(:merchant_classification, merchant_name: "ローソン", category_key: "food")
    category = create(:category, user: user, category_key: "food", name: "食費")

    expect(CategoryClassifier.category_id_for(user, "ローソン")).to eq(category.id)
  end

  it "merchant_name を正規化して照合する（全角/前後空白違いを吸収）" do
    create(:merchant_classification, merchant_name: "Amazon", category_key: "food")
    category = create(:category, user: user, category_key: "food", name: "食費")

    expect(CategoryClassifier.category_id_for(user, " Ａｍａｚｏｎ ")).to eq(category.id)
  end

  it "大文字小文字が違っても一致する（正規化で吸収）" do
    create(:merchant_classification, merchant_name: "Amazon", category_key: "food")
    category = create(:category, user: user, category_key: "food", name: "食費")

    expect(CategoryClassifier.category_id_for(user, "amazon")).to eq(category.id)
    expect(CategoryClassifier.category_id_for(user, "AMAZON")).to eq(category.id)
  end

  it "分類キーはあるが user にそのカテゴリが無ければ nil" do
    create(:merchant_classification, merchant_name: "X", category_key: "food")
    expect(CategoryClassifier.category_id_for(user, "X")).to be_nil
  end

  it "merchant_name が空なら nil" do
    expect(CategoryClassifier.category_id_for(user, nil)).to be_nil
    expect(CategoryClassifier.category_id_for(user, "   ")).to be_nil
  end
end
