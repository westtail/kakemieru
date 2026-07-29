class PasswordsController < ApplicationController
  allow_unauthenticated_access
  # リセットメールの大量送信（email bombing）を抑止する。
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { redirect_to new_password_url, alert: "しばらく待ってから再度お試しください。" }
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    # normalizes は find_by にも適用されるため、大文字/空白混じりのメールでも該当ユーザーを引ける。
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    # ユーザーの存在有無を漏らさないため、常に同じメッセージを返す。
    redirect_to new_session_path, notice: "パスワード再設定の手順をメールで送信しました（登録がある場合）。"
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      # 乗っ取り復旧のため、既存の全セッション（攻撃者の端末を含む）を無効化する。
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "パスワードを更新しました。改めてログインしてください。"
    else
      # redirect ではなく再描画し、@user.errors を表示する（原因が分かるようにする）。
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      # 署名不正・期限切れに加え、トークンは有効でもユーザーが削除済み（RecordNotFound）の場合も
      # 500 にせず、無効リンクとして再設定申請画面へ誘導する。
      redirect_to new_password_path, alert: "パスワード再設定のリンクが無効か、有効期限が切れています。"
    end
end
