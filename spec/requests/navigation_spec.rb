require "rails_helper"

RSpec.describe "グローバルナビ", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  describe "ログイン時" do
    before { sign_in }

    it "全ページ共通ヘッダーに主要画面へのリンクとログアウトを表示する" do
      get "/"
      expect(response.body).to include('id="global-nav"')
      expect(response.body).to include(transactions_path, new_import_path,
        categories_path, payment_methods_path, account_path)
      expect(response.body).to include("ログアウト")
    end

    it "トップ以外の画面でもヘッダーを表示する" do
      get transactions_path
      expect(response.body).to include('id="global-nav"')
    end

    it "現在のページのナビ項目を現在地として強調する（aria-current=page + nav-link-active）" do
      get categories_path
      # カテゴリのリンクがアクティブ表示になる。
      expect(response.body).to match(%r{<a[^>]*class="nav-link-active"[^>]*>\s*カテゴリ})
      expect(response.body).to include('aria-current="page"')
    end

    it "別ページでは無関係のナビ項目はアクティブにならない" do
      get payment_methods_path
      # 支払方法がアクティブ、カテゴリは非アクティブ（nav-link）。
      expect(response.body).to match(%r{<a[^>]*class="nav-link-active"[^>]*>\s*支払方法})
      expect(response.body).to match(%r{<a[^>]*class="nav-link"[^>]*>\s*カテゴリ})
    end

    it "「取り込み」はドロップダウンで CSV/手動/履歴の3項目を持つ" do
      get "/"
      expect(response.body).to include('data-controller="dropdown"')
      # 3項目のリンクがサーバーレンダリングされている（表示切替は Stimulus）
      expect(response.body).to include(new_import_path(anchor: "csv-import"))
      expect(response.body).to include(new_import_path(anchor: "manual-import"))
      expect(response.body).to include(imports_path)
    end
  end

  describe "未ログイン時" do
    it "ログイン画面には共通ヘッダーを表示しない" do
      get "/sign_in"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('id="global-nav"')
    end
  end
end
