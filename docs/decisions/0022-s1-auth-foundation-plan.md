# ADR-0022: S1 認証基盤の実装計画

- 日付: 2026-07-03
- ステータス: 提案中
- 関連: [ADR-0011 認証方式の選定](0011-authentication-strategy.md) / [ADR-0010 テストフレームワーク](0010-testing-framework.md)
- 対象 Issue: #15 / #16 / #17 / #18

---

## コンテキスト

フェーズ1（MVP）の最初の実装単位 S1「基盤」に着手する。
S1 は認証基盤一式であり、以下の 4 Issue で構成される。

| Issue | 内容 |
|---|---|
| #15 | SimpleCov 設定（カバレッジ目標 80%） |
| #16 | [migration] users / sessions テーブル |
| #17 | User モデル + spec |
| #18 | 認証コントローラ・ビュー + spec（ログイン・ログアウト） |

認証方式は ADR-0011 で **Rails 8 Built-in Authentication**（`bin/rails generate authentication`）を採用済み。
本 ADR では S1 の「実装方針・分割単位・テスト方針」を確定させ、実装前の合意点とする。

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

依存関係に基づき、**3 PR** に分割する。

```
PR-1  chore/15-simplecov         #15  … 独立（他に依存しない）
PR-2  feat/16-auth-scaffold      #16 #17  … generator 実行 + データ層
PR-3  feat/18-auth-sessions      #18      … PR-2 に依存（認証フロー）
```

- **PR-1（#15）**: SimpleCov は認証と無関係のテスト基盤。先行して独立マージ可能。
- **PR-2（#16 + #17）**: `generate authentication` をここで実行し、
  マイグレーション（users/sessions）+ User モデルのカスタマイズ + モデル spec までを含める。
  generator が生成する `SessionsController` 等も同時に入るが、この PR では
  **生成された既定状態のまま**とし、カスタマイズは PR-3 で行う。
- **PR-3（#18）**: `SessionsController`・ビューのカスタマイズ（`/sign_in` 化・
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

### #15 SimpleCov

- `spec_helper.rb` 冒頭で SimpleCov 起動、`coverage/` 出力
- `config/` `db/` `spec/` `bin/` 等を除外
- カバレッジ 80% 未満で失敗する（`minimum_coverage 80`）
- 検証: `bundle exec rspec` 後に `coverage/index.html` 生成

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
PR-1  #15 SimpleCov（RED: 設定 → GREEN: 既存 home_spec で緑）
  ↓
PR-2  #16 #17
   1. bin/rails generate authentication
   2. マイグレーション修正（admin 追加・email_address 一意インデックス確認）
   3. migrate / rollback / migrate:redo 確認・schema.rb レビュー
   4. User モデル spec（RED）→ バリデーション・関連の実装（GREEN）
  ↓
PR-3  #18
   1. Sessions リクエスト spec（RED）
   2. ルート /sign_in 化・SessionsController/ビュー調整・require_authentication（GREEN）
```

---

## 未決・保留

- S1-S2 の Fly.io 実機確認（#20）は S2 完了後にまとめて実施
- E2E（#54）はフェーズ1後半の E2E 環境構築（#55）後

---

## 参考

- [ADR-0011 認証方式の選定](0011-authentication-strategy.md)
- [AUTHENTICATION.md](../design/AUTHENTICATION.md)
- [DATABASE_DESIGN.md](../design/DATABASE_DESIGN.md)
