require "rails_helper"

RSpec.describe "Passwords", type: :request do
  let(:password) { "password123" }
  let!(:user) { create(:user, email_address: "user@example.com", password: password) }

  # 存在有無を漏らさないため、既知/未知で同一の文言を返すことを検証する。
  RESET_NOTICE = "パスワード再設定の手順をメールで送信しました（登録がある場合）。".freeze

  describe "POST /passwords（リセット申請）" do
    it "既知のメールにはリセットメールを送り、汎用メッセージでログイン画面へ戻る" do
      expect do
        post "/passwords", params: { email_address: user.email_address }
      end.to have_enqueued_mail(PasswordsMailer, :reset)

      expect(response).to redirect_to("/sign_in")
      expect(flash[:notice]).to eq(RESET_NOTICE)
    end

    it "未知のメールではメールを送らず、既知の場合と同一のメッセージ・遷移を返す（ユーザー列挙防止）" do
      expect do
        post "/passwords", params: { email_address: "nobody@example.com" }
      end.not_to have_enqueued_mail(PasswordsMailer, :reset)

      expect(response).to redirect_to("/sign_in")
      expect(flash[:notice]).to eq(RESET_NOTICE)
    end

    it "大文字・空白混じりのメールでも正規化して該当ユーザーに送る" do
      expect do
        post "/passwords", params: { email_address: "  USER@Example.COM " }
      end.to have_enqueued_mail(PasswordsMailer, :reset)
    end
  end

  describe "PATCH /passwords/:token（再設定）" do
    it "有効なトークンで新しいパスワードに更新できる" do
      token = user.password_reset_token

      patch "/passwords/#{token}", params: { password: "newpassword", password_confirmation: "newpassword" }

      expect(response).to redirect_to("/sign_in")
      expect(user.reload.authenticate("newpassword")).to be_truthy
    end

    it "再設定に成功すると既存のセッションが無効化される（乗っ取り復旧）" do
      user.sessions.create!(ip_address: "127.0.0.1", user_agent: "old-device")
      token = user.password_reset_token

      expect do
        patch "/passwords/#{token}", params: { password: "newpassword", password_confirmation: "newpassword" }
      end.to change { user.sessions.count }.from(1).to(0)
    end

    it "パスワードが短すぎると edit を再描画しエラーを表示、パスワードは変わらない" do
      token = user.password_reset_token

      patch "/passwords/#{token}", params: { password: "short", password_confirmation: "short" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "パスワードと確認が不一致なら edit を再描画し、パスワードは変わらない" do
      token = user.password_reset_token

      patch "/passwords/#{token}", params: { password: "newpassword", password_confirmation: "different1" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "無効・期限切れトークンはリセット申請画面へリダイレクトする" do
      patch "/passwords/invalid-token", params: { password: "newpassword", password_confirmation: "newpassword" }

      expect(response).to redirect_to("/passwords/new")
    end

    it "トークンは有効でもユーザー削除済みなら 500 にならずリダイレクトする" do
      token = user.password_reset_token
      user.destroy

      patch "/passwords/#{token}", params: { password: "newpassword", password_confirmation: "newpassword" }

      expect(response).to redirect_to("/passwords/new")
    end
  end
end
