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

  describe "POST /500（via: :all・CSRF スキップ）" do
    it "POST でも 500 のエラーページを返す（例外時に POST がディスパッチされても通る）" do
      post "/500"
      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("サーバーエラーが発生しました")
    end
  end

  describe "実例外の exceptions_app 経由（config.exceptions_app = routes）" do
    # 本番同様に例外ミドルウェアで処理させ、実例外→ブランド化ページの配線を検証する。
    around do |example|
      env_config = Rails.application.env_config
      original = env_config["action_dispatch.show_exceptions"]
      original_detailed = env_config["action_dispatch.show_detailed_exceptions"]
      env_config["action_dispatch.show_exceptions"] = :all
      env_config["action_dispatch.show_detailed_exceptions"] = false
      example.run
    ensure
      env_config["action_dispatch.show_exceptions"] = original
      env_config["action_dispatch.show_detailed_exceptions"] = original_detailed
    end

    it "存在しないパスは exceptions_app 経由でブランド化 404 を返す" do
      get "/no/such/path/exists"
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("見つかりません")
    end
  end

  describe "ヘルスチェック" do
    it "GET /health は 200 を返す" do
      get "/health"
      expect(response).to have_http_status(:ok)
    end
  end
end
