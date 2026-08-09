require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /sign_up" do
    it "登録フォームを表示する" do
      get "/sign_up"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("メールアドレス", "パスワード", "登録")
    end
  end

  describe "POST /sign_up" do
    let(:valid_params) do
      { email_address: "new@example.com", password: "password123", password_confirmation: "password123" }
    end

    context "有効な入力" do
      it "ユーザーを作成して自動ログインし、ダッシュボードへ遷移する" do
        expect do
          post "/sign_up", params: valid_params
        end.to change(User, :count).by(1)

        expect(response).to redirect_to("/")

        # 自動ログイン済み：保護画面に入れる
        get "/"
        expect(response).to have_http_status(:ok)
      end

      it "パスワードは authenticate で検証できる状態で保存される" do
        post "/sign_up", params: valid_params
        expect(User.find_by(email_address: "new@example.com").authenticate("password123")).to be_truthy
      end
    end

    context "admin パラメータを送っても権限昇格しない" do
      it "admin は false のまま作成される" do
        post "/sign_up", params: valid_params.merge(admin: true)
        expect(User.find_by(email_address: "new@example.com").admin).to be(false)
      end
    end

    context "無効な入力" do
      it "既に使われているメールでは作成しない（大文字・空白違いも正規化して弾く）" do
        create(:user, email_address: "new@example.com")
        expect do
          post "/sign_up", params: valid_params.merge(email_address: "  NEW@Example.COM ")
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "全項目未入力では作成しない" do
        expect do
          post "/sign_up", params: {}
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "失敗時にメールは再表示に保持し、パスワードは埋め戻さない" do
        post "/sign_up", params: valid_params.merge(email_address: "keep@example.com", password: "short12", password_confirmation: "short12")
        expect(response.body).to include("keep@example.com")
        expect(response.body).not_to include("short12")
      end

      it "不正な形式のメールでは作成しない" do
        expect do
          post "/sign_up", params: valid_params.merge(email_address: "invalid")
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "パスワードが短すぎると作成しない" do
        expect do
          post "/sign_up", params: valid_params.merge(password: "short12", password_confirmation: "short12")
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "パスワードと確認が不一致だと作成しない" do
        expect do
          post "/sign_up", params: valid_params.merge(password_confirmation: "different1")
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "レート制限" do
      it "先頭10回は許可され、11回目の登録が遮断される" do
        10.times do
          post "/sign_up", params: { email_address: "x@example.com", password: "short12", password_confirmation: "short12" }
          # バリデーション失敗（422）であって、遮断（リダイレクト）ではないことを確認する。
          expect(response).to have_http_status(:unprocessable_entity)
        end

        post "/sign_up", params: valid_params
        expect(response).to redirect_to("/sign_up")
        expect(User.exists?(email_address: "new@example.com")).to be(false)
      end
    end
  end
end
