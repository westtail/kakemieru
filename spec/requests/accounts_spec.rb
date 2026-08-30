require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:password) { "password123" }
  let!(:user) { create(:user, email_address: "user@example.com", password: password) }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  describe "PATCH /account/settings（取込設定・ADR-0047/0048）" do
    before { sign_in }

    it "店舗ルール・特別ルールの自動適用トグルを個別にオンにできる" do
      patch account_settings_path, params: { user: {
        auto_apply_merchant_rules_on_import: "1", auto_apply_special_rules_on_import: "1"
      } }
      expect(response).to redirect_to(account_path)
      user.reload
      expect(user.auto_apply_merchant_rules_on_import).to be(true)
      expect(user.auto_apply_special_rules_on_import).to be(true)
    end

    it "片方だけオンにできる（未送信の他方はオフ）" do
      user.update!(auto_apply_merchant_rules_on_import: true, auto_apply_special_rules_on_import: true)
      patch account_settings_path, params: { user: { auto_apply_special_rules_on_import: "1" } }
      user.reload
      expect(user.auto_apply_merchant_rules_on_import).to be(false) # 未送信はオフ
      expect(user.auto_apply_special_rules_on_import).to be(true)
    end

    it "両方未送信は両方オフとして保存する" do
      user.update!(auto_apply_merchant_rules_on_import: true, auto_apply_special_rules_on_import: true)
      patch account_settings_path, params: { user: {} }
      user.reload
      expect(user.auto_apply_merchant_rules_on_import).to be(false)
      expect(user.auto_apply_special_rules_on_import).to be(false)
    end

    it "未ログインはログイン画面へ" do
      delete "/sign_out"
      patch account_settings_path, params: { user: { auto_apply_merchant_rules_on_import: "1" } }
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "未認証アクセス" do
    it "各アクションはログイン画面へリダイレクトする" do
      get "/account"
      expect(response).to redirect_to("/sign_in")
      patch "/account/email", params: { current_password: password, email_address: "x@example.com" }
      expect(response).to redirect_to("/sign_in")
      patch "/account/password", params: { current_password: password, password: "newpassword", password_confirmation: "newpassword" }
      expect(response).to redirect_to("/sign_in")
      delete "/account", params: { current_password: password, confirmation: "退会する" }
      expect(response).to redirect_to("/sign_in")
      expect(User.exists?(user.id)).to be(true)
      get "/account/delete"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "GET /account" do
    it "認証済みならアカウント設定を表示する" do
      sign_in
      get "/account"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.email_address)
    end
  end

  describe "PATCH /account/email（メールアドレス変更）" do
    before { sign_in }

    it "現在のパスワードと有効なメールで変更でき、アカウント設定へ戻る" do
      patch "/account/email", params: { current_password: password, email_address: "new@example.com" }
      expect(user.reload.email_address).to eq("new@example.com")
      expect(response).to redirect_to("/account")
      expect(flash[:notice]).to be_present
    end

    it "大文字・空白混じりのメールは正規化して保存する" do
      patch "/account/email", params: { current_password: password, email_address: "  NEW@Example.COM " }
      expect(user.reload.email_address).to eq("new@example.com")
    end

    it "現在のパスワードが未送信なら変更しない" do
      patch "/account/email", params: { email_address: "new@example.com" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.email_address).to eq("user@example.com")
    end

    it "現在のパスワードが誤りなら変更しない" do
      patch "/account/email", params: { current_password: "wrong-password", email_address: "new@example.com" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.email_address).to eq("user@example.com")
    end

    it "不正な形式のメールは変更しない" do
      patch "/account/email", params: { current_password: password, email_address: "invalid" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.email_address).to eq("user@example.com")
    end

    it "既に使われているメールは変更しない" do
      create(:user, email_address: "taken@example.com")
      patch "/account/email", params: { current_password: password, email_address: "taken@example.com" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.email_address).to eq("user@example.com")
    end
  end

  describe "PATCH /account/password（パスワード変更）" do
    before { sign_in }

    it "現在のパスワードが正しく新パスワードが有効なら変更できる" do
      patch "/account/password", params: { current_password: password, password: "newpassword", password_confirmation: "newpassword" }
      expect(user.reload.authenticate("newpassword")).to be_truthy
    end

    it "現在のパスワードが誤りなら変更しない" do
      patch "/account/password", params: { current_password: "wrong-password", password: "newpassword", password_confirmation: "newpassword" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "新パスワードが空・確認欄未送信なら変更しない" do
      patch "/account/password", params: { current_password: password, password: "", password_confirmation: "" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "新パスワードと確認が不一致なら変更しない" do
      patch "/account/password", params: { current_password: password, password: "newpassword", password_confirmation: "different1" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "新パスワードが短すぎると変更しない" do
      patch "/account/password", params: { current_password: password, password: "short12", password_confirmation: "short12" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "変更成功で自分以外のセッションは失効し、現在のセッションは維持される" do
      user.sessions.create!(ip_address: "10.0.0.1", user_agent: "other-device")

      patch "/account/password", params: { current_password: password, password: "newpassword", password_confirmation: "newpassword" }

      expect(user.sessions.count).to eq(1)
      get "/account"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "退会" do
    before { sign_in }

    it "GET /account/delete は退会確認画面を表示する" do
      get "/account/delete"
      expect(response).to have_http_status(:ok)
    end

    it "現在のパスワードと確認文字列が一致するとユーザーと全セッションが削除される" do
      other_session = user.sessions.create!(ip_address: "10.0.0.1", user_agent: "other-device")

      expect do
        delete "/account", params: { current_password: password, confirmation: "退会する" }
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to("/sign_in")
      expect(User.exists?(user.id)).to be(false)
      expect(Session.exists?(other_session.id)).to be(false)
    end

    it "確認文字列が不一致なら退会しない" do
      expect do
        delete "/account", params: { current_password: password, confirmation: "やめる" }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "現在のパスワードが誤りなら退会しない" do
      expect do
        delete "/account", params: { current_password: "wrong-password", confirmation: "退会する" }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
