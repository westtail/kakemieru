require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }
  let!(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  describe "未ログイン" do
    it "一覧・新規はログイン画面へリダイレクトする" do
      get "/transactions"
      expect(response).to redirect_to("/sign_in")
      get "/transactions/new"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "GET /transactions/new" do
    it "入力フォームを表示する" do
      sign_in
      get "/transactions/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("利用日", "金額", "店舗名")
    end
  end

  describe "POST /transactions（手動1件入力）" do
    before { sign_in }

    it "明細を作成する（import_id = NULL・保存後に月別一覧へ）" do
      category = create(:category, user: user, name: "食費")
      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: 1200, merchant_name: "ローソン",
                         payment_method_id: payment_method.id, category_id: category.id }
        }
      end.to change { user.transactions.count }.by(1)

      created = user.transactions.order(:id).last
      expect(created.import_id).to be_nil
      expect(created.amount).to eq(1200)
      expect(created.effective_amount).to eq(1200)
      expect(response).to redirect_to("/transactions?month=2026-01")
    end

    it "カテゴリ未選択（未分類）でも作成できる" do
      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: 500, merchant_name: "自販機",
                         payment_method_id: payment_method.id, category_id: "" }
        }
      end.to change { user.transactions.count }.by(1)
      expect(user.transactions.order(:id).last.category_id).to be_nil
    end

    it "必須項目が空だとエラーを再描画する" do
      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: "", merchant_name: "",
                         payment_method_id: payment_method.id }
        }
      end.not_to change { user.transactions.count }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
    end

    it "他ユーザーの支払方法/カテゴリは紐づけられない（テナント整合）" do
      other = create(:user)
      others_pm = create(:payment_method, user: other, name: "他人カード")
      others_cat = create(:category, user: other, name: "他人カテゴリ")

      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: 100, merchant_name: "x",
                         payment_method_id: others_pm.id, category_id: others_cat.id }
        }
      end.not_to change(Transaction, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /transactions（月別一覧）" do
    before { sign_in }

    it "指定月の明細のみ表示する" do
      in_month = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 1, 10), merchant_name: "1月の店")
      other_month = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 2, 10), merchant_name: "2月の店")

      get "/transactions", params: { month: "2026-01" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1月の店")
      expect(response.body).not_to include("2月の店")
    end

    it "他ユーザーの明細は表示しない" do
      other = create(:user)
      others_pm = create(:payment_method, user: other)
      create(:transaction, user: other, payment_method: others_pm, date: Date.new(2026, 1, 10), merchant_name: "他人の明細")

      get "/transactions", params: { month: "2026-01" }
      expect(response.body).not_to include("他人の明細")
    end
  end
end
