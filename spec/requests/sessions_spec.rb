require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:password) { "password123" }
  let!(:user) { create(:user, email_address: "user@example.com", password: password) }

  describe "GET /sign_in" do
    it "ログインフォームを表示する" do
      get "/sign_in"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("メールアドレス", "パスワード", "ログイン")
    end
  end

  describe "POST /sign_in（ログイン）" do
    context "正しい資格情報" do
      it "ダッシュボードにリダイレクトしセッションを確立する" do
        expect do
          post "/sign_in", params: { email_address: user.email_address, password: password }
        end.to change(Session, :count).by(1)

        expect(response).to redirect_to("/")

        # セッションが確立され、保護画面に入れる
        get "/"
        expect(response).to have_http_status(:ok)
      end
    end

    context "誤った資格情報" do
      it "ログイン画面に戻りエラーを表示し、セッションは作られない" do
        expect do
          post "/sign_in", params: { email_address: user.email_address, password: "wrong-password" }
        end.not_to change(Session, :count)

        expect(response).to redirect_to("/sign_in")
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /sign_out（ログアウト）" do
    it "ログイン画面にリダイレクトしセッションを破棄する" do
      post "/sign_in", params: { email_address: user.email_address, password: password }

      expect do
        delete "/sign_out"
      end.to change(Session, :count).by(-1)

      expect(response).to redirect_to("/sign_in")

      # 破棄後は保護画面に入れない
      get "/"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "未認証で保護画面にアクセス" do
    it "ログイン画面にリダイレクトする" do
      get "/"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "ログイン後の return-to 復帰" do
    it "未認証で要求した URL（クエリ付き）にログイン後に戻る" do
      get "/?month=2026-01"
      expect(response).to redirect_to("/sign_in")

      post "/sign_in", params: { email_address: user.email_address, password: password }
      expect(response).to redirect_to("/?month=2026-01")
    end
  end
end
