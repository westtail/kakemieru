require "rails_helper"

RSpec.describe "エラーページ・ヘルスチェック", type: :request do
  describe "動的エラーページ（ブランド化・未ログインでも表示）" do
    it "GET /404 は 404 で案内文を表示する" do
      get "/404"
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("見つかりません")
      # エラーページはログイン画面へリダイレクトしない
      expect(response).not_to redirect_to("/sign_in")
    end

    it "GET /422 は 422 を返す" do
      get "/422"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("処理できません")
    end

    it "GET /500 は 500 を返す" do
      get "/500"
      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("サーバーエラーが発生しました")
    end

    it "エラーページは DB/セッションに依存しない最小レイアウト（ヘッダー無し）で描画する" do
      get "/404"
      # ログイン時のみ出るグローバルナビを描画しない（認証チェックで DB を触らない）。
      expect(response.body).not_to include('id="global-nav"')
    end
  end

  describe "ヘルスチェック" do
    it "GET /health は 200 を返す" do
      get "/health"
      expect(response).to have_http_status(:ok)
    end
  end
end
