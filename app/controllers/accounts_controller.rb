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

    if change_password(password_params)
      redirect_to account_path, notice: "パスワードを変更しました。"
    else
      render :show, status: :unprocessable_entity
    end
  end

  # 取込設定（店舗ルールの取込時自動適用トグル・ADR-0047）。低リスクな設定変更のため
  # パスワード再確認は求めない。チェックボックス未送信は false として確実に反映する。
  def update_settings
    # チェックボックス未送信は params に現れない。Boolean.cast(nil) は nil を返すため、
    # NOT NULL 列に nil を入れないよう明示的に false へ倒す。
    enabled = ActiveModel::Type::Boolean.new.cast(params.dig(:user, :auto_apply_rules_on_import)) || false
    if Current.user.update(auto_apply_rules_on_import: enabled)
      redirect_to account_path, notice: "取込設定を保存しました。"
    else
      redirect_to account_path, alert: "取込設定の保存に失敗しました。時間をおいて再度お試しください。"
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

    unless params[:confirmation] == "退会する"
      Current.user.errors.add(:base, "確認の文字列が一致しません。")
      return render :confirm_deletion, status: :unprocessable_entity
    end

    if Current.user.destroy
      cookies.delete(:session_id)
      redirect_to new_session_path, notice: "退会しました。ご利用ありがとうございました。"
    else
      Current.user.errors.add(:base, "退会処理に失敗しました。時間をおいて再度お試しください。")
      render :confirm_deletion, status: :unprocessable_entity
    end
  end

  private
    def authenticated_with_current_password?
      Current.user.authenticate(params[:current_password].to_s)
    end

    # パスワード更新と他セッションの失効を原子的に行う。
    # 途中で失敗したら両方ロールバックし、「パスワードは変わったが他セッションが残る」不整合を防ぐ。
    def change_password(password_params)
      ActiveRecord::Base.transaction do
        Current.user.update!(password_params)
        # 現在のセッションは維持し、他端末のセッションを失効させる。
        Current.user.sessions.where.not(id: Current.session.id).destroy_all
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    def render_show_with_current_password_error
      Current.user.errors.add(:base, "現在のパスワードが正しくありません。")
      render :show, status: :unprocessable_entity
    end
end
