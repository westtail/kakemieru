require "rails_helper"

RSpec.describe "MerchantRules", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }
  let!(:food) { create(:category, user: user, name: "食費") }
  let!(:transport) { create(:category, user: user, name: "交通費") }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  describe "POST /merchant_rules" do
    it "店舗ルールを登録する（店舗名は正規化して保存）" do
      sign_in
      post merchant_rules_path, params: { merchant_classification: { merchant_name: " Ｌａｗｓｏｎ ", category_id: food.id } }

      expect(response).to redirect_to(categories_path(anchor: "merchant-rules"))
      rule = user.merchant_classifications.sole
      expect(rule.merchant_name).to eq("lawson")
      expect(rule.category_id).to eq(food.id)
    end

    it "既に登録済みの店舗は重複登録しない" do
      create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
      sign_in

      expect do
        post merchant_rules_path, params: { merchant_classification: { merchant_name: "ローソン", category_id: transport.id } }
      end.not_to change(MerchantClassification, :count)
      expect(flash[:alert]).to be_present
    end

    it "空の店舗名は登録できない" do
      sign_in
      expect do
        post merchant_rules_path, params: { merchant_classification: { merchant_name: "", category_id: food.id } }
      end.not_to change(MerchantClassification, :count)
      expect(flash[:alert]).to be_present
    end

    it "他ユーザーのカテゴリでは登録できない（テナント整合）" do
      others_category = create(:category, user: create(:user), name: "他人")
      sign_in
      expect do
        post merchant_rules_path, params: { merchant_classification: { merchant_name: "X", category_id: others_category.id } }
      end.not_to change(MerchantClassification, :count)
      expect(flash[:alert]).to be_present
    end

    it "未ログインはログイン画面へ" do
      post merchant_rules_path, params: { merchant_classification: { merchant_name: "X", category_id: food.id } }
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "PATCH /merchant_rules/:id" do
    let!(:rule) { create(:merchant_classification, user: user, category: food, merchant_name: "ローソン") }

    it "カテゴリを変更する" do
      sign_in
      patch merchant_rule_path(rule), params: { merchant_classification: { category_id: transport.id } }

      expect(response).to redirect_to(categories_path(anchor: "merchant-rules"))
      expect(rule.reload.category_id).to eq(transport.id)
    end

    it "他ユーザーのルールは 404" do
      other = create(:user)
      others_rule = create(:merchant_classification, user: other, category: create(:category, user: other), merchant_name: "A")
      sign_in
      patch merchant_rule_path(others_rule), params: { merchant_classification: { category_id: food.id } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /merchant_rules/:id" do
    let!(:rule) { create(:merchant_classification, user: user, category: food, merchant_name: "ローソン") }

    it "店舗ルールを削除する" do
      sign_in
      expect do
        delete merchant_rule_path(rule)
      end.to change(MerchantClassification, :count).by(-1)
      expect(response).to redirect_to(categories_path(anchor: "merchant-rules"))
    end

    it "他ユーザーのルールは 404" do
      other = create(:user)
      others_rule = create(:merchant_classification, user: other, category: create(:category, user: other), merchant_name: "A")
      sign_in
      delete merchant_rule_path(others_rule)
      expect(response).to have_http_status(:not_found)
    end
  end
end
