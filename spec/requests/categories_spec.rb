require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  describe "未ログイン" do
    it "一覧はログイン画面へリダイレクトする" do
      get "/categories"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "GET /categories（一覧）" do
    it "初期カテゴリと独自カテゴリをセクション分離で表示する" do
      create(:category, :initial, user: user, name: "食費")
      create(:category, user: user, name: "推し活")
      sign_in

      get "/categories"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("初期カテゴリ", "独自カテゴリ", "食費", "推し活")
    end
  end

  describe "POST /categories（追加）" do
    before { sign_in }

    it "独自カテゴリを追加できる（key は NULL）" do
      expect do
        post "/categories", params: { category: { name: "推し活" } }
      end.to change { user.categories.count }.by(1)

      created = user.categories.order(:id).last
      expect(created.name).to eq("推し活")
      expect(created.category_key).to be_nil
      expect(response).to redirect_to("/categories")
    end

    it "名前が重複すると追加できず、エラーを再描画する" do
      create(:category, user: user, name: "推し活")
      expect do
        post "/categories", params: { category: { name: "推し活" } }
      end.not_to change { user.categories.count }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
    end
  end

  describe "PATCH /categories/:id（名前変更）" do
    before { sign_in }

    it "独自カテゴリの名前を変更できる" do
      category = create(:category, user: user, name: "推し活")
      patch "/categories/#{category.id}", params: { category: { name: "趣味" } }
      expect(category.reload.name).to eq("趣味")
      expect(response).to redirect_to("/categories")
    end

    it "初期カテゴリも名前は変更できる（key は保持される）" do
      category = create(:category, :initial, user: user, name: "食費")
      key = category.category_key
      patch "/categories/#{category.id}", params: { category: { name: "食料品" } }
      expect(category.reload.name).to eq("食料品")
      expect(category.category_key).to eq(key)
    end
  end

  describe "DELETE /categories/:id（削除）" do
    before { sign_in }

    it "独自カテゴリは削除できる" do
      category = create(:category, user: user, name: "推し活")
      expect do
        delete "/categories/#{category.id}"
      end.to change { user.categories.count }.by(-1)
      expect(response).to redirect_to("/categories")
    end

    it "初期カテゴリは削除できない（拒否して残る）" do
      category = create(:category, :initial, user: user, name: "食費")
      expect do
        delete "/categories/#{category.id}"
      end.not_to change { user.categories.count }
      expect(response).to redirect_to("/categories")
      expect(flash[:alert]).to be_present
    end
  end

  describe "所有権による認可（他ユーザーのカテゴリ）" do
    let(:other) { create(:user) }
    let!(:others_category) { create(:category, user: other, name: "他人のカテゴリ") }

    before { sign_in }

    it "他ユーザーのカテゴリは変更できない（404・不変）" do
      patch "/categories/#{others_category.id}", params: { category: { name: "乗っ取り" } }
      expect(response).to have_http_status(:not_found)
      expect(others_category.reload.name).to eq("他人のカテゴリ")
    end

    it "他ユーザーのカテゴリは削除できない（404・不変）" do
      expect do
        delete "/categories/#{others_category.id}"
      end.not_to change(Category, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
