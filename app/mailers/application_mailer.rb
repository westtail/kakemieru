class ApplicationMailer < ActionMailer::Base
  # 送信元は環境変数で差し替える。
  # - 本番: Resend で検証済みドメインのアドレス（例 "KakeMieru <noreply@your-domain>"）を MAIL_FROM に。
  # - 検証用: 未設定なら Resend のサンドボックス onboarding@resend.dev（自分の登録メール宛にのみ送れる）。
  default from: ENV.fetch("MAIL_FROM", "KakeMieru <onboarding@resend.dev>")
  layout "mailer"
end
