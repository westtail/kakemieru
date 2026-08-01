class AccountsController < ApplicationController
  # 現在パスワードのオンライン推測（セッション奪取後の総当り）を抑止する。
  rate_limit to: 10, within: 3.minutes, only: %i[update_email update_password destroy],
             with: -> { redirect_to account_path, alert: "しばらく待ってから再度お試しください。" }

  def show
  end

  def update_email
    return render_show_with_current_password_error unless authenticated_with_current_password?

    if Current.user.update(email_address: params[:email_address].to_s)
      redirect_to account_path, notice: "メールアドレスを変更しました。"
    else
      # 失敗時は代入済みの不正値を元に戻し、画面の「現在:」に反映されないようにする。
      Current.user.restore_attributes([ :email_address ])
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    return render_show_with_current_password_error unless authenticated_with_current_password?

    # permit 後の値で presence を判定する（配列など非スカラは permit で除去され blank 扱いになる）。
    password_params = params.permit(:password, :password_confirmation)
    if password_params[:password].blank? || password_params[:password_confirmation].blank?
      Current.user.errors.add(:password, :blank) if password_params[:password].blank?
      Current.user.errors.add(:password_confirmation, :blank) if password_params[:password_confirmation].blank?
      return render :show, status: :unprocessable_entity
    end

    if Current.user.update(password_params)
      # 現在のセッションは維持し、他端末のセッションを失効させる。
      Current.user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to account_path, notice: "パスワードを変更しました。"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def confirm_deletion
  end

  def destroy
    # 退会は最も破壊的なため、他の変更操作と同様に現在パスワードを要求する。
    unless authenticated_with_current_password?
      Current.user.errors.add(:base, "現在のパスワードが正しくありません。")
      return render :confirm_deletion, status: :unprocessable_entity
    end

    if params[:confirmation] == "退会する"
      Current.user.destroy
      cookies.delete(:session_id)
      redirect_to new_session_path, notice: "退会しました。ご利用ありがとうございました。"
    else
      Current.user.errors.add(:base, "確認の文字列が一致しません。")
      render :confirm_deletion, status: :unprocessable_entity
    end
  end

  private
    def authenticated_with_current_password?
      Current.user.authenticate(params[:current_password].to_s)
    end

    def render_show_with_current_password_error
      Current.user.errors.add(:base, "現在のパスワードが正しくありません。")
      render :show, status: :unprocessable_entity
    end
end
