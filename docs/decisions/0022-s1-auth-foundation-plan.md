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
- **[#19 で対応済み] パスワードリセットのレート制限** — `PasswordsController#create` に `rate_limit 5回/3分` を追加（email bombing 対策）。
- **[#19 で確認・訂正] パスワードリセットのメール正規化** — 当初「`find_by(email_address:)` は `normalizes` が効かない」と記載したが**誤り**。Rails 7.1+ の `normalizes` は finder（`find_by`）のキーワード引数にも適用されるため、大文字/空白混じりのメールでも該当ユーザーを引ける（#19 の request spec で実証）。手動 `.strip.downcase` は不要で、追加対応なし。
- **[#19 で対応済み] `PasswordsController#update` のエラー表示** — 失敗時に `redirect_to ..., alert: "Passwords did not match."` だと実バリデーションエラーと乖離し `@user.errors` も失われる問題を、`render :edit, status: :unprocessable_entity` + `passwords/edit.html.erb` での `@user.errors.full_messages` 表示に変更。
- **[#19 で対応済み] `PasswordsController#set_user_by_token` の例外未処理** — `find_by_password_reset_token!` はユーザー削除済みだと `ActiveRecord::RecordNotFound` を送出し 500 になる問題を、rescue に `ActiveRecord::RecordNotFound` を追加して無効リンク扱い（`new_password_path` へリダイレクト）に修正。
- **[#19 で対応済み] パスワードリセット成功時のセッション無効化** — `update` 成功時に `@user.sessions.destroy_all` で既存セッション（攻撃者端末含む）を失効。乗っ取り復旧の目的を満たす（request spec で検証）。
- **横断（別 Issue 化推奨）: i18n 未整備** — `default_locale` が `:en` で `@user.errors.full_messages` 等が英語表示（日本語UIに混在）。password リセットに限らず登録/ログイン全画面に影響するため、`config/locales/ja.yml`（`activerecord.attributes`・`errors.messages`）追加と `default_locale = :ja` を横断タスクとして実施する。
- **#18 以降: セッション有効期限** — 現状は permanent cookie で実質無期限。`sessions` に `last_active_at`/`expires_at` を追加し、アイドルタイムアウト/絶対有効期限を検討。
- **インフラ: `trusted_proxies`** — Fly.io 配下で `request.remote_ip` を監査保存するため、`config.action_dispatch.trusted_proxies` の確認（IP 偽装対策）。

## リリース条件（セキュリティゲート）

上記「引き継ぎ事項」は**実装順序**の話であり、本番公開の可否は本節のゲートで管理する。
以下は **#20（初回 Fly.io デプロイ・本番での認証有効化）の必須ブロッカー**とし、
満たさない場合はデプロイを見送る。CodeRabbit のセキュリティ指摘（レート制限なしでの
出荷・無期限セッション）への対応方針。

- **[ブロッカー] パスワードリセットのレート制限（#19）** — 未実装のまま本番で認証フローを公開しない。
- **[ブロッカー] セッションの最低限の失効** — 最低限 cookie の有効期間を permanent から妥当な長さに短縮する（アイドルタイムアウト等の作り込みは後続可）。盗難セッションの有効期間を限定する。
- **検証**: #20 の実機確認チェックリストに上記2点を含め、リリース前に確認する。
- リスク受容者: #20 デプロイ実施者（リポジトリメンテナ）。

## 未決・保留

- S1-S2 の Fly.io 実機確認（#20）は S2 完了後にまとめて実施
- E2E（#54）はフェーズ1後半の E2E 環境構築（#55）後

---

## 参考

- [ADR-0011 認証方式の選定](0011-authentication-strategy.md)
- [AUTHENTICATION.md](../design/AUTHENTICATION.md)
- [DATABASE_DESIGN.md](../design/DATABASE_DESIGN.md)
