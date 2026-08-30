require "rails_helper"

RSpec.describe "SpecialRules", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }
  let!(:food) { create(:category, user: user, name: "食費") }
  let!(:hobby) { create(:category, user: user, name: "娯楽") }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  def valid_attrs(overrides = {})
    { merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200, category_id: hobby.id, note: "Netflix" }.merge(overrides)
  end

  describe "未ログイン" do
    it "一覧はログイン画面へリダイレクトする" do
      get special_rules_path
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "GET /special_rules" do
    it "登録済みの特別ルールを表示する" do
      create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200, note: "Netflix")
      sign_in
      get special_rules_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("特別ルール", "楽天SP", "Netflix")
    end
  end

  describe "POST /special_rules" do
    before { sign_in }

    it "特別ルールを登録する（店舗名は正規化して保存）" do
      expect do
        post special_rules_path, params: { special_rule: valid_attrs(merchant_name: " 楽天ＳＰ ") }
      end.to change(SpecialRule, :count).by(1)
      expect(response).to redirect_to(special_rules_path)
      rule = user.special_rules.sole
      expect(rule.merchant_name).to eq("楽天sp")
      expect(rule.category_id).to eq(hobby.id)
      expect(rule.note).to eq("Netflix")
    end

    it "判別条件（金額・日）が無ければ 422 で再描画する" do
      expect do
        post special_rules_path, params: { special_rule: valid_attrs(amount_min: nil, amount_max: nil, day_of_month: nil) }
      end.not_to change(SpecialRule, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "amount_max < amount_min は 422" do
      post special_rules_path, params: { special_rule: valid_attrs(amount_min: 2000, amount_max: 1000) }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "他ユーザーのカテゴリでは登録できない（テナント整合）" do
      others_category = create(:category, user: create(:user), name: "他人")
      expect do
        post special_rules_path, params: { special_rule: valid_attrs(category_id: others_category.id) }
      end.not_to change(SpecialRule, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /special_rules/:id" do
    let!(:rule) { create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200) }

    it "条件やカテゴリを変更できる" do
      sign_in
      patch special_rule_path(rule), params: { special_rule: { category_id: food.id, amount_max: 1500 } }
      expect(response).to redirect_to(special_rules_path)
      rule.reload
      expect(rule.category_id).to eq(food.id)
      expect(rule.amount_max).to eq(1500)
    end

    it "他ユーザーのルールは 404" do
      other = create(:user)
      others_rule = create(:special_rule, user: other, category: create(:category, user: other), merchant_name: "A", amount_min: 1, amount_max: 1)
      sign_in
      patch special_rule_path(others_rule), params: { special_rule: { amount_max: 2 } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /special_rules/:id" do
    let!(:rule) { create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200) }

    it "特別ルールを削除する" do
      sign_in
      expect { delete special_rule_path(rule) }.to change(SpecialRule, :count).by(-1)
      expect(response).to redirect_to(special_rules_path)
    end

    it "他ユーザーのルールは 404" do
      other = create(:user)
      others_rule = create(:special_rule, user: other, category: create(:category, user: other), merchant_name: "A", amount_min: 1, amount_max: 1)
      sign_in
      delete special_rule_path(others_rule)
      expect(response).to have_http_status(:not_found)
    end
  end
end
