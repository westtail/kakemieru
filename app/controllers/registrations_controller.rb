class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  # 自動化されたアカウント大量作成（スパム登録）を抑止する。
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_registration_url, alert: "しばらく待ってから再度お試しください。" }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      # 登録後に自動ログインし、ダッシュボードへ。
      start_new_session_for @user
      redirect_to root_path, notice: "アカウントを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # admin など特権属性を絶対に permit しない（権限昇格対策）。
    def registration_params
      params.permit(:email_address, :password, :password_confirmation)
    end
end
