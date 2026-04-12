# ADR-0021: メール送信サービスの選定

- 日付: 2026-04-12
- ステータス: 決定済み

---

## コンテキスト

パスワードリセット機能（`/passwords/new`）でメール送信が必要になる。
Fly.io はアウトバウンドのポート25（SMTP）をブロックしているため、外部メール送信サービスが必須。

---

## 検討した選択肢

| サービス | 無料枠 | 特徴 |
|---|---|---|
| **Resend** | 3,000件/月・100件/日 | モダンな API。Rails 連携が簡単。個人・ポートフォリオ用途に最適 |
| Postmark | 100件/月 | 到達率が高い。無料枠が少ない |
| SendGrid | 100件/日 | 大手。設定がやや複雑 |
| Brevo | 300件/日 | 無料枠は多いが UI が煩雑 |

---

## 決定事項

### Resend を採用する

**理由**
- 無料枠 3,000件/月で個人利用には十分すぎる（パスワードリセットしか送らない）
- ActionMailer の SMTP 設定だけで動く。gem 追加不要
- Fly.io secrets に API キーを登録するだけでデプロイ完結
- モダンなサービスで Rails との相性がよい

**ActionMailer の設定方針**

```ruby
# config/environments/production.rb
config.action_mailer.smtp_settings = {
  address:              "smtp.resend.com",
  port:                 465,
  domain:               ENV["APP_DOMAIN"],       # kakemieru.fly.dev など
  user_name:            "resend",
  password:             ENV["RESEND_API_KEY"],   # Fly.io secrets で管理
  authentication:       "login",
  enable_starttls_auto: true
}
config.action_mailer.default_url_options = { host: ENV["APP_DOMAIN"] }
```

**Fly.io secrets への登録**

```bash
fly secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
fly secrets set APP_DOMAIN=kakemieru.fly.dev
```

**送信するメール（フェーズ1）**

| メール | 送信タイミング |
|---|---|
| パスワードリセット | `/passwords/new` でリクエスト時 |

- From アドレス: `noreply@kakemieru.fly.dev`（Resend の無料枠はサブドメイン送信可）
- 開発環境では Letter Opener を使いブラウザでプレビュー（実際には送信しない）

---

## 保留事項

- カスタムドメイン取得後は From を `noreply@kakemieru.app` 等に変更（フェーズ2以降）
- ユーザー向けの通知メール（月次レポートなど）はフェーズ3以降
