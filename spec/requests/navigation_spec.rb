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
  end

  describe "未ログイン時" do
    it "ログイン画面には共通ヘッダーを表示しない" do
      get "/sign_in"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('id="global-nav"')
    end
  end
end
