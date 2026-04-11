# 認証方式の調査・比較

最終更新: 2026-04-05

---

> **採用方針（ADR-0011 で確定）**
> - フェーズ1: **Rails 8 Built-in Authentication**（以下の比較表の「1」）
> - フェーズ2以降: パスキー（webauthn-rails）→ OmniAuth の順で段階的に拡張
> - Devise は採用しない

---

## 概要

Rails 8 で利用できる認証方式の比較と KakeMieru への適用検討。
ポートフォリオとして技術チャレンジ要素も含めて選定する。

---

## 各認証方式の特徴

### 1. Rails 8 Built-in Authentication

```bash
bin/rails generate authentication
```

**生成されるもの**
- `User` モデル（`has_secure_password`）
- `Session` モデル（トークン・IP・ユーザーエージェント追跡）
- `SessionsController`（ログイン/ログアウト）
- `PasswordsController`（パスワードリセット）
- マイグレーション・ビュー・ルート

**できること**
- メール+パスワード認証
- 複数セッション管理（Devise の Trackable は最新1件のみだが、こちらは全セッション追跡可能）
- パスワードリセット

**できないこと**（手動実装が必要）
- サインアップフロー
- ソーシャルログイン
- メール確認
- パスキー認証（別 gem が必要）
- アカウントロック・MFA

**評価**
- シンプルで Rails の仕組みが理解しやすい
- カスタマイズ性が高い
- Rails 8 のネイティブ機能なので面接でアピールしやすい

---

### 2. Devise

**主なモジュール**

| モジュール | 機能 |
|---|---|
| Registerable | ユーザー登録 |
| Recoverable | パスワードリセット |
| Rememberable | 次回自動ログイン |
| Confirmable | メール確認 |
| Trackable | ログイン追跡（最新1件） |
| Timeoutable | セッションタイムアウト |
| Lockable | アカウントロック |

**メリット**
- 機能が豊富で本番環境向け
- コミュニティが大きく資料が豊富
- Rails 8 完全対応（Devise 5.0.0：2026年1月リリース）

**デメリット**
- 「魔法」が多くカスタマイズが複雑
- 学習コストが高い
- パスキー対応は別 gem（devise-passkeys）

---

### 3. パスキー（Passkeys / WebAuthn）

**仕組み**
- WebAuthn 標準に基づいた passwordless 認証
- ユーザーの端末に秘密鍵を保存、サーバーは公開鍵を保持
- 指紋認証・顔認証と連動
- パスワード不要で高セキュリティ

**Rails で使える Gem**

| Gem | 特徴 | 向き |
|---|---|---|
| `webauthn-rails` | Rails 8 ネイティブ統合 | 新規プロジェクト向け |
| `devise-passkeys` | Devise 拡張 | 既存 Devise プロジェクト向け |
| `passkeys-rails` | API・モバイルフォーカス | API 開発向け |
| `rodauth` | 60以上の認証機能を個別有効化 | 高度なカスタマイズ向け |

**参考**
- [Passkey authentication in Rails 8 with webauthn-rails](https://medium.com/cedarcode/passkey-authentication-in-rails-8-with-webauthn-rails-c58333abae26)

---

### 4. OmniAuth（ソーシャルログイン）

**対応プロバイダー**
- Google（`omniauth-google-oauth2`）
- GitHub（`omniauth-github`）
- Apple（`omniauth-apple`）
- その他多数

**基本フロー**
1. プロバイダーの Developer Console で credentials 取得
2. OmniAuth middleware を設定
3. コールバック処理でユーザーレコード作成/更新

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET']
  provider :github, ENV['GITHUB_CLIENT_ID'], ENV['GITHUB_CLIENT_SECRET']
end
```

**Rails 8 Built-in との組み合わせも可能**
- [Social login with the Rails 8 auth generator](https://avohq.io/blog/social-login-auth-generator)

---

## 方式比較

| | Rails 8 Built-in | Devise | Devise + Passkeys | Rails 8 + webauthn |
|---|---|---|---|---|
| セットアップ速度 | 高速 | 中速 | 低速 | 中速 |
| 学習コスト | 低 | 高 | 高 | 中 |
| カスタマイズ性 | 高 | 低 | 低 | 高 |
| セッション管理 | 優れている | 基本的 | 基本的 | 優れている |
| パスキー対応 | 別 gem | 別 gem | ネイティブ | ネイティブ |
| ソーシャルログイン | 手動 | OmniAuth | OmniAuth | OmniAuth |

---

## ポートフォリオ向け構成パターン

### パターン A: シンプル重視
```
Rails 8 Built-in Authentication のみ
```
- メール+パスワード認証
- コードが理解しやすい
- Rails の仕組みを示せる

### パターン B: モダン重視（推奨）
```
Rails 8 Built-in + webauthn-rails + OmniAuth
```
- パスキー対応（業界トレンド）
- Google / GitHub ソーシャルログイン
- 最新技術のキャッチアップをアピール

### パターン C: 実戦派
```
Devise v5.0.0 + devise-passkeys + OmniAuth
```
- 豊富な機能
- 本番環境レベルの実装
- 大規模プロジェクトでの採用実績多数

### パターン D: 技術チャレンジ
```
Rails 8 Built-in + Rodauth
```
- 60以上の認証機能から必要なものだけ有効化
- MFA（多要素認証）実装
- セキュリティへのこだわりをアピール

---

## KakeMieru への適用方針

### 実装ロードマップ

**フェーズ1: Rails 8 Built-in（バニラ実装）**
- メール+パスワード認証を自前で実装
- コードが全部自分のものなので面接で全部説明できる状態にする
- Rails 5 時代のバニラ実装との差分（`has_secure_password`・`Current`・Session モデルなど）を理解する

**フェーズ2（後で）: パスキー追加**
- `webauthn-rails` を追加
- 既存の Built-in 認証にパスキーを乗せる

**フェーズ3（後で）: ソーシャルログイン追加**
- OmniAuth で Google / GitHub ログインを追加

### Devise との比較を残す
実装しながら「Devise だとこの部分がブラックボックスになっている」という対比をコメントやドキュメントに記録していく。
Devise の内部理解は、Built-in を理解した後に読むと見通しが良くなる。

### 管理画面の認証
同じ認証基盤を使いつつ `admin` フラグで管理者を判定する方針が最もシンプル。

---

## 参考ソース

- [Rails 8 Built-in Authentication Generator | Saeloun Blog](https://blog.saeloun.com/2025/05/12/rails-8-adds-built-in-authentication-generator/)
- [Building authentication in Rails 2026 — WorkOS](https://workos.com/blog/rails-authentication-guide-2026)
- [Rails 8 Authentication: Devise vs Built-In Options | Nonstopio](https://blog.nonstopio.com/rails-8-authentication-devise-vs-clearance-vs-built-in-options-2169e91e8bcc)
- [Passkey authentication in Rails 8 with webauthn-rails | Cedarcode](https://medium.com/cedarcode/passkey-authentication-in-rails-8-with-webauthn-rails-c58333abae26)
- [Migrating from Devise to Rails Auth | Radan Skorić](https://radanskoric.com/guest-articles/from-devise-to-rails-auth)
- [devise-passkeys GitHub](https://github.com/ruby-passkeys/devise-passkeys)
- [passkeys-rails GitHub](https://github.com/alliedcode/passkeys-rails)
- [Passkeys in Rails: The end of passwords? – Nimble](https://nimblehq.co/blog/passkeys-rails-end-of-passwords)
- [Social login with the Rails 8 auth generator | Avo](https://avohq.io/blog/social-login-auth-generator)
- [Adding Google OAuth in Rails 8 | Jeremy Kreutzbender](https://jeremykreutzbender.com/blog/adding-google-oauth-in-rails-8)
- [Passkey Authentication with Rodauth | DEV Community](https://dev.to/janko/passkey-authentication-with-rodauth-4p8j)
- [The State of Authentication in Rails 2026 | Medium](https://medium.com/@brandynbb96/the-state-of-authentication-in-rails-in-2026-a-comparison-between-laravel-django-and-next-js-a3c52c085961)
