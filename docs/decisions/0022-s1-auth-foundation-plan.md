# ADR-0022: S1 認証基盤の実装計画

- 日付: 2026-07-03
- ステータス: 提案中
- 関連: [ADR-0011 認証方式の選定](0011-authentication-strategy.md) / [ADR-0010 テストフレームワーク](0010-testing-framework.md)
- 対象 Issue: #16 / #17 / #18

> テスト基盤（SimpleCov #15）は本 ADR の対象外。認証設計とは独立したテスト環境整備のため別途対応する。

---

## コンテキスト

フェーズ1（MVP）の最初の実装単位 S1「基盤」のうち、認証基盤に着手する。
認証基盤は以下の 3 Issue で構成される。

| Issue | 内容 |
|---|---|
| #16 | [migration] users / sessions テーブル |
| #17 | User モデル + spec |
| #18 | 認証コントローラ・ビュー + spec（ログイン・ログアウト） |

認証方式は ADR-0011 で **Rails 8 Built-in Authentication**（`bin/rails generate authentication`）を採用済み。
本 ADR では認証基盤の「実装方針・分割単位・テスト方針」を確定させ、実装前の合意点とする。

---

## 論点と決定

### 1. ジェネレータ出力は 1 コマンドで大半が生成される

`bin/rails generate authentication` は以下を **一括生成** する。

- モデル: `User`(has_secure_password) / `Session` / `Current`
- コントローラ: `SessionsController` / `PasswordsController` / concern `Authentication`
- ビュー: `sessions/new` / `passwords/*` / メーラビュー
- マイグレーション: users / sessions
- ルート・`PasswordsMailer`・`bcrypt` の有効化

→ #16（migration）・#17（User モデル）・#18（コントローラ/ビュー）の土台は
**物理的に 1 コマンドの出力に混在する**。Issue ごとに完全分離してブランチを切ると、
generator 出力の取り合いが発生し依存順序の管理が煩雑になる。

### 2. ブランチ・PR 分割方針（決定）

依存関係に基づき、**2 PR** に分割する。

```
PR-1  feat/16-auth-scaffold      #16 #17  … generator 実行 + データ層
PR-2  feat/18-auth-sessions      #18      … PR-1 に依存（認証フロー）
```

- **PR-1（#16 + #17）**: `generate authentication` をここで実行し、
  マイグレーション（users/sessions）+ User モデルのカスタマイズ + モデル spec までを含める。
  generator が生成する `SessionsController` 等も同時に入るが、この PR では
  **生成された既定状態のまま**とし、カスタマイズは PR-2 で行う。
- **PR-2（#18）**: `SessionsController`・ビューのカスタマイズ（`/sign_in` 化・
  `require_authentication` による全画面保護・エラーメッセージ）+ リクエスト spec。

> 「1 ブランチ = 1 Issue」の原則から #16 と #17 のみ束ねる。理由は generator 出力が
> 両者に不可分に跨るため。PR 本文で両 Issue を `Closes #16, closes #17` で閉じる。

### 3. カラム命名: `email_address` に統一（決定）

- DB 設計書（[DATABASE_DESIGN.md](../design/DATABASE_DESIGN.md)）は `email`
- Issue #16 と Rails 8 ジェネレータは `email_address`

→ ジェネレータ準拠で **`email_address`** に統一する。
`DATABASE_DESIGN.md` の `users.email` は後続の docs 修正で `email_address` に追随させる。

### 4. `admin` カラムはマイグレーションに追加（決定）

ジェネレータ既定の users には `admin` が無い。ADR-0011 の「`admin` フラグで管理者判定」に従い、
マイグレーションに `admin:boolean default: false, null: false` を追加する。

### 5. User の関連は「存在するモデルのみ」宣言（決定）

Issue #17 は `has_many :transactions, :payment_methods, :imports, :categories` を挙げるが、
これらのテーブル・モデルは S3〜S7 で作成される。S1 時点で宣言しても spec で担保できない。

→ S1 では **`has_many :sessions, dependent: :destroy` のみ**宣言する。
他の関連は各テーブルを作る S 単位（S3 categories / S4 payment_methods / S5 imports / S7 transactions）で、
そのモデル・spec と一緒に追加する。本 ADR にトレーサビリティとして明記。

---

## テスト方針（TDD: RED → GREEN → REFACTOR）

実装前に spec を先に書き（RED）、レビューで合意してから実装に入る。

### #17 User モデル spec（`spec/models/user_spec.rb`）

| 観点 | ケース |
|---|---|
| バリデーション | email_address 必須 / 一意（大文字小文字無視）/ メール形式 |
| パスワード | has_secure_password（authenticate 成功・失敗） |
| 既定値 | admin が false |
| 関連 | has_many :sessions / dependent: :destroy でセッション連鎖削除 |

- FactoryBot: `spec/factories/users.rb`

### #18 Sessions リクエスト spec（`spec/requests/sessions_spec.rb`）

| ケース | 期待 |
|---|---|
| ログイン成功 | `/` へリダイレクト・セッション確立 |
| ログイン失敗 | `/sign_in` で再描画・エラーメッセージ |
| ログアウト | `/sign_in` へリダイレクト・セッション破棄 |
| 未ログインで保護画面 | `/sign_in` へリダイレクト |

---

## 実装順序

```
PR-1  #16 #17
   1. bin/rails generate authentication
   2. マイグレーション修正（admin 追加・email_address 一意インデックス確認）
   3. migrate / rollback / migrate:redo 確認・schema.rb レビュー
   4. User モデル spec（RED）→ バリデーション・関連の実装（GREEN）
  ↓
PR-2  #18
   1. Sessions リクエスト spec（RED）
   2. ルート /sign_in 化・SessionsController/ビュー調整・require_authentication（GREEN）
```

---

## セキュリティ引き継ぎ事項（レビュー指摘・後続対応）

PR-1 のブランチレビュー（security-reviewer / code-reviewer）で挙がった、後続 Issue で必ず対応する項目。

- **#18/#21: `admin` の権限昇格対策（HIGH）** — ユーザー作成/更新の strong parameters で `admin` を**絶対に permit しない**。加えて `attr_readonly :admin` 等でモデル層でも防御し、リクエスト spec で「admin=true を送っても昇格しない」を検証する。
- **#19: パスワードリセットのレート制限** — `PasswordsController#create` に `rate_limit`（例: 5回/3分）を追加（email bombing 対策）。
- **#19: パスワードリセットのメール正規化** — `PasswordsController` の `find_by(email_address:)` は `normalizes` が効かないため、`params[:email_address]&.strip&.downcase` で引く（大文字メールでリセットが届かない機能バグの回避）。
- **#19: `PasswordsController#update` のエラー表示** — 生成デフォルトは失敗時に `redirect_to ..., alert: "Passwords did not match."` で、実際のバリデーションエラー（短すぎ・空など）と乖離し `@user.errors` も失われる。PR-1 で追加した最小長バリデーション（`password` minimum: 8）でこの乖離が顕在化。`render :edit, status: :unprocessable_entity` に変更し、`passwords/edit.html.erb` で `@user.errors.full_messages` を表示する。あわせて flash/エラー表示を部分テンプレート（例 `shared/_flash`）に寄せる。
- **#19: `PasswordsController#set_user_by_token` の例外未処理** — `find_by_password_reset_token!`（Rails 8.0.4 では内部で `find(id)` を使用）は、トークン署名が有効でもユーザーが削除済みだと `ActiveRecord::RecordNotFound` を送出する。現状は `ActiveSupport::MessageVerifier::InvalidSignature` のみ rescue のため 500 になる。rescue に `ActiveRecord::RecordNotFound` を追加し、無効リンクと同じ扱い（`new_password_path` へリダイレクト）にする。CodeRabbit 指摘・Rails ソースで確認済み。
- **#18 以降: セッション有効期限** — 現状は permanent cookie で実質無期限。`sessions` に `last_active_at`/`expires_at` を追加し、アイドルタイムアウト/絶対有効期限を検討。
- **インフラ: `trusted_proxies`** — Fly.io 配下で `request.remote_ip` を監査保存するため、`config.action_dispatch.trusted_proxies` の確認（IP 偽装対策）。

## 未決・保留

- S1-S2 の Fly.io 実機確認（#20）は S2 完了後にまとめて実施
- E2E（#54）はフェーズ1後半の E2E 環境構築（#55）後

---

## 参考

- [ADR-0011 認証方式の選定](0011-authentication-strategy.md)
- [AUTHENTICATION.md](../design/AUTHENTICATION.md)
- [DATABASE_DESIGN.md](../design/DATABASE_DESIGN.md)
