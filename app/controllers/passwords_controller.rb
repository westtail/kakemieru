class PasswordsController < ApplicationController
  allow_unauthenticated_access
  # IP 単位: 連打の一次抑止。
  rate_limit to: 5, within: 3.minutes, only: :create, name: "reset-ip",
             with: -> { redirect_to new_password_url, alert: "しばらく待ってから再度お試しください。" }
  # メールアドレス単位: IP を分散されても、特定アドレスへのメール爆撃を抑止する。
  # 正規化キー（strip+downcase＝User の normalizes と同じ）で大文字/空白違いの回避を防ぐ。
  # 存在有無に関わらず一律に効くためユーザー列挙は漏れない。
  # トレードオフ: 攻撃者が枠を消費して正規ユーザーのリセットを一時的に妨げ得るため、緩めの上限にする。
  rate_limit to: 5, within: 1.hour, only: :create, name: "reset-email",
             by: -> { params[:email_address].to_s.strip.downcase },
             with: -> { redirect_to new_password_url, alert: "しばらく待ってから再度お試しください。" }
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    # normalizes は find_by にも適用されるため、大文字/空白混じりのメールでも該当ユーザーを引ける。
    if user = User.find_by(email_address: params[:email_address])
      send_reset_email(user)
    end

    # ユーザーの存在有無を漏らさないため、常に同じメッセージを返す。
    redirect_to new_session_path, notice: "パスワード再設定の手順をメールで送信しました（登録がある場合）。"
  end

  def edit
  end

  def update
    reset_params = params.permit(:password, :password_confirmation)

    # has_secure_password は password 未送信（nil）だと既存 digest を保持したまま update が
    # 成功扱いになり、confirmation も nil だと確認検証がスキップされる（Rails 8.0.4）。
    # そのため両フィールドの presence を明示チェックし、空なら更新もセッション破棄もしない。
    if reset_params[:password].blank? || reset_params[:password_confirmation].blank?
      @user.errors.add(:password, :blank) if reset_params[:password].blank?
      @user.errors.add(:password_confirmation, :blank) if reset_params[:password_confirmation].blank?
      render :edit, status: :unprocessable_entity
    elsif @user.update(reset_params)
      # 乗っ取り復旧のため、既存の全セッション（攻撃者の端末を含む）を無効化する。
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "パスワードを更新しました。改めてログインしてください。"
    else
      # redirect ではなく再描画し、@user.errors を表示する（原因が分かるようにする）。
      render :edit, status: :unprocessable_entity
    end
  end

  private
    # メールは deliver_now で同期送信する（バックグラウンドジョブを持たない方針）。
    # 送信が失敗（Resend 障害等）しても、存在するユーザーだけ 500 になるとレスポンス差で
    # ユーザー列挙が漏れるため、rescue して応答は常に同一にする。
    # ただし恒常障害（API キー欠落・テンプレエラー等）を無言で握り潰すと「メール全断」に
    # 気づけないため、backtrace まで error ログに残す（監視で拾えるようにする）。
    # 補足: deliver_now は送信を同期実行するため、存在ユーザー（送信あり=遅い）と
    # 非存在（即リダイレクト=速い）でレイテンシ差が残る（タイミング列挙）。SMTP タイムアウトで
    # 上限を絞りつつ、主防御は IP 単位の rate_limit とする（受容リスク）。
    def send_reset_email(user)
      PasswordsMailer.reset(user).deliver_now
    rescue => e
      Rails.logger.error("Password reset email delivery failed: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace
    end

    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      # 署名不正・期限切れに加え、トークンは有効でもユーザーが削除済み（RecordNotFound）の場合も
      # 500 にせず、無効リンクとして再設定申請画面へ誘導する。
      redirect_to new_password_path, alert: "パスワード再設定のリンクが無効か、有効期限が切れています。"
    end
end
