# ADR-0011: 認証方式の選定

- 日付: 2026-04-05
- ステータス: 決定済み（パスキー・OAuthは保留）

---

## コンテキスト

KakeMieru に認証機能を実装するにあたり、方式を選定する必要があった。
業務では Devise を使用しているが、ポートフォリオとしての技術理解・説明能力の向上も目的に含む。

**検討の背景**
- 業務で Devise を使っているが「中身がブラックボックス」になっている
- Rails 8 で Built-in Authentication Generator が新たに提供された
- パスキー・ソーシャルログインも将来的に追加したい
- 面接で「なぜこの実装か」を説明できる状態にしたい

---

## 検討した選択肢

### A. Devise
- 豊富な機能が揃っている
- 業務でも広く使われており資料が多い
- Rails 8 完全対応（Devise 5.0.0：2026年1月リリース）
- **課題**: 内部がブラックボックスになりやすく、カスタマイズが複雑

### B. Rails 8 Built-in Authentication（バニラ）
- `rails generate authentication` 1コマンドでベースを生成
- 生成コードが全部自分のプロジェクトに入るためカスタマイズが容易
- セッション管理が Devise より優れている（全セッション履歴を追跡可能）
- **課題**: サインアップ・メール確認などは自前実装が必要

### C. Devise + webauthn（パスキー）+ OmniAuth
- 機能網羅性が高い
- **課題**: 学習コストが高く、初期実装として複雑すぎる

---

## 決定事項

### フェーズ1: Rails 8 Built-in Authentication を採用

**理由**
- 生成コードが全部自分のものになるため、処理の流れを完全に説明できる
- Rails 5 時代のバニラ実装との差分（`has_secure_password`・`Current`・Session モデル）を実際に体験して理解する
- 面接での説明能力を高めることが目的の一つであり、「中身を知っている」状態が重要
- Devise の内部理解は Built-in を理解した後に行う方が見通しがよい

**実装方針**
- `rails generate authentication` でベースを生成
- サインアップフローは手動実装
- `admin` フラグで管理者権限を制御（管理画面向け）

### フェーズ2以降（保留）: パスキー追加
- `webauthn-rails` gem を追加
- 既存の Built-in 認証にパスキーを乗せる形で実装

### フェーズ3以降（保留）: ソーシャルログイン追加
- OmniAuth で Google / GitHub ログインを追加
- `omniauth-google-oauth2`・`omniauth-github` を使用

---

## Devise との比較記録方針

実装しながら「Devise だとこの部分がブラックボックスになっている」という対比をコメントやドキュメントに残していく。これにより Devise の内部理解も深める。

---

## 結果

詳細な各方式の比較は [AUTHENTICATION.md](../AUTHENTICATION.md) を参照。

---

## 参考ソース

- [Rails 8 Built-in Authentication Generator | Saeloun Blog](https://blog.saeloun.com/2025/05/12/rails-8-adds-built-in-authentication-generator/)
- [Building authentication in Rails 2026 — WorkOS](https://workos.com/blog/rails-authentication-guide-2026)
- [Migrating from Devise to Rails Auth | Radan Skorić](https://radanskoric.com/guest-articles/from-devise-to-rails-auth)
- [Passkey authentication in Rails 8 with webauthn-rails | Cedarcode](https://medium.com/cedarcode/passkey-authentication-in-rails-8-with-webauthn-rails-c58333abae26)
- [Social login with the Rails 8 auth generator | Avo](https://avohq.io/blog/social-login-auth-generator)
