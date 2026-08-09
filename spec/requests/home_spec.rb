require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "未認証のとき" do
      it "ログイン画面にリダイレクトする" do
        get root_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "認証済みのとき" do
      let(:password) { "password123" }
      let(:user) { create(:user, password: password) }

      before do
        post "/sign_in", params: { email_address: user.email_address, password: password }
      end

      it "ダッシュボードを表示する" do
        get root_path
        expect(response).to have_http_status(:success)
      end

      it "アプリタイトルを表示する" do
        get root_path
        expect(response.body).to include("掛け見える - 家計簿アプリ")
      end

      it "稼働中ステータスを表示する" do
        get root_path
        expect(response.body).to match(/アプリケーション稼働中/)
      end
    end
  end
end
