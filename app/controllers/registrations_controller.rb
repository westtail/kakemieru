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

    if create_user_with_default_categories
      # 登録後に自動ログインし、ダッシュボードへ。
      start_new_session_for @user
      redirect_to root_path, notice: "アカウントを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # ユーザー作成と初期カテゴリのコピーを1トランザクションで原子的に行う。
    # 途中で失敗したら両方ロールバックし、「ユーザーはいるがカテゴリが空」を防ぐ。
    # バリデーションエラー時は false を返し（save が false）、:new を再描画させる。
    def create_user_with_default_categories
      ActiveRecord::Base.transaction do
        next false unless @user.save
        Category.copy_templates_to(@user)
        true
      end
    end

    # admin など特権属性を絶対に permit しない（権限昇格対策）。
    def registration_params
      params.permit(:email_address, :password, :password_confirmation)
    end
end
