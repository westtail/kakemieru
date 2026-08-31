# ADR-0024: S3 カテゴリ機能の実装計画

- 日付: 2026-08-09
- ステータス: 承認（2026-08-09 論点1-4 確定）
- 関連: [ADR-0015 カテゴリ分類方針](0015-category-classification-strategy.md) / [ADR-0013 DBモデル設計](0013-database-model-design.md) / [ADR-0017 DB設計クリティカル修正](0017-db-design-critical-fixes.md) / [ADR-0022 S1認証基盤](0022-s1-auth-foundation-plan.md)
- 対象 Issue: #23 / #24 / #25（#21 のカテゴリコピー部分に影響）

---

## コンテキスト

フェーズ1の実装単位 S3「カテゴリ」に着手する。CSV 取り込み時の自動分類（S5-6）や明細の分類（S7-8）の土台となる。

| Issue | 内容 |
|---|---|
| #23 | [migration] category_templates / categories テーブル + シード |
| #24 | CategoryTemplate・Category モデル + spec |
| #25 | カテゴリ管理画面 CRUD + spec |

カテゴリは **テンプレートコピー方式**（ADR-0015）: システム共通の `category_templates` を持ち、ユーザー登録時に各ユーザーの `categories`（`user_id NOT NULL`）へコピーする。

---

## テーブル設計（決定）

### category_templates（システム共通・不変）

| カラム | 型 | 制約 |
|---|---|---|
| id | bigint | PK |
| category_key | string | NOT NULL / UNIQUE |
| name | string | NOT NULL |
| timestamps | | |

- 初期 12 件（food/dining_out/transport/daily/entertainment/clothing/medical/utilities/communication/subscription/education/other）。
- `category_key` は将来 `merchant_classifications` との紐づけに使う（S5）。

### categories（ユーザーごと）

| カラム | 型 | 制約 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | NOT NULL / FK → users |
| category_key | string | nullable（独自カテゴリは NULL） |
| name | string | NOT NULL |
| timestamps | | |

**インデックス（3種・すべて必須）**
- `UNIQUE (user_id, name)` … 同一ユーザー内で名前重複を禁止
- `UNIQUE (user_id, category_key) WHERE category_key IS NOT NULL` … 初期カテゴリの重複コピー防止（Postgres 部分ユニークインデックス）
- `UNIQUE (user_id, id)` … **S7 の transactions 複合FK `(user_id, category_id) → categories(user_id, id)` の参照先**。Rails は主キーしか参照しないため複合UNIQUEを別途張る。**transactions が無い S3 の時点で先に用意しておく**（後付けだと既存行との整合が面倒）。

### 初期/独自の区別（`category_key` の有無で表現）

- `category_key IS NOT NULL` = **初期カテゴリ**（テンプレ由来）: **名前変更のみ可・削除不可**
- `category_key IS NULL` = **独自カテゴリ**（ユーザー作成）: 追加・名前変更・削除すべて可

### 「未分類」の扱い

- 専用レコードは持たない。`transactions.category_id = NULL` が未分類を表す（S7）。UI のセレクトで先頭に空 value の特殊オプションとして出す。

---

## 論点と決定

### 1. `has_many :transactions` / nullify は S7 に後回し（決定）

#24 は `has_many :transactions, dependent: :nullify` とその spec を挙げるが、**Transaction モデル/テーブルは S7** で作られる。ADR-0022 決定#5（存在するモデルの関連のみ宣言する）に従い、S3 では宣言しない。

- S3 の `Category` は `belongs_to :user` のみ宣言。
- カテゴリ削除は S3 では**単純な destroy**（紐づく明細がまだ無い）。
- **DB レベルの `SET NULL`（FK ON DELETE SET NULL）と `has_many :transactions, dependent: :nullify` は S7 で transactions と一緒に追加**する。#24/#25 の「nullify 動作」テストも S7 に移す。本 ADR にトレーサビリティとして明記。

### 2. 登録時のカテゴリ自動コピー（#21 の一部）を S3 に含める（決定・確認済み 2026-08-09）

新規ユーザーは `categories` が空だと #25 の「初期カテゴリ」セクションが空になり機能が成立しない。categories テーブルができた今、**#21 の「登録時にテンプレートをコピー」を S3 で実装**して機能を完結させる。

- 実装: `Category.copy_templates_to(user)`（`category_templates` 全件を `category_key` + `name` でコピー）を **`RegistrationsController#create` の登録成功時に呼ぶ**。
- User の `after_create` にはしない（全テストのユーザー生成で12件生成されてファクトリが重くなる/結合が増えるのを避ける）。
- #21 の残り（`payment_type: cash` の「現金」自動生成）は payment_methods が無いため **S4 に残す**。

### 3. category_templates の本番投入は「データ投入マイグレーション」で行う（決定・確認済み 2026-08-09）

`db/seeds.rb` は**既存の本番DBでは自動実行されない**（`db:prepare` は新規作成時のみ seed を走らせる）。過去に「本番でテーブル未作成 → 500」を踏んだ教訓から、**12件のテンプレートは冪等なデータ投入マイグレーション**（`find_or_create_by(category_key:)` 相当を SQL/モデルで）に入れ、`db:migrate` で確実に本番へ入るようにする。

- `db/seeds.rb` にも同じ内容を冪等に置き、開発/テストの `db:seed` でも入るようにする（二重管理にならないよう定数 `config/constants` 等で一元化）。
- 代替案（seeds.rb のみ + 本番で手動 `db:seed`）は運用ミスの温床になるため採らない。

### 4. カテゴリキーの定数管理（決定）

12 の `category_key` と既定 `name` は `config/constants/`（DATABASE_DESIGN の方針）に定数として一元化し、マイグレーション・seed・モデルから参照する。

---

## テスト方針（TDD: RED → GREEN → REFACTOR）

### #23 マイグレーション

- `rails db:migrate` 正常完了 / `rails db:rollback STEP=2` / `rails db:migrate:redo STEP=2`
- `db/schema.rb` レビュー（3インデックス・部分ユニーク・NOT NULL）
- データ投入マイグレーションの冪等性（2回流しても12件のまま）

### #24 モデル spec（`spec/models/category_spec.rb` / `category_template_spec.rb`）

| 対象 | ケース |
|---|---|
| Category | name 必須 / user_id 必須 |
| Category | 同一 user_id で name 重複 → エラー |
| Category | 異なる user_id で同名 → OK |
| Category | belongs_to :user |
| CategoryTemplate | category_key 必須・一意 |
| コピー | `Category.copy_templates_to(user)` で 12 件生成・key/name 一致 |

- FactoryBot: `spec/factories/categories.rb`（初期＝category_key あり / 独自＝category_key nil の trait）

### #25 リクエスト spec（`spec/requests/categories_spec.rb`）

| ケース | 期待 |
|---|---|
| 一覧 | 初期/独自がセクション分離で表示・要ログイン |
| 追加成功 | 独自カテゴリ作成 → 一覧に出る |
| 追加失敗 | name 重複 → エラー再描画 |
| 名前変更 | 初期・独自ともに rename 可 |
| 削除（独自） | 削除できる |
| 削除（初期）不可 | category_key ありは削除拒否 |
| 認可 | 他ユーザーのカテゴリを操作できない（`Current.user.categories` スコープ） |

> 「他ユーザーのカテゴリを触れない」= 本アプリで**初めて登場する所有権ベースの認可**。全 action を `Current.user.categories` 経由にして担保する。

### 登録フロー spec（#21 コピー部分）

- サインアップ成功時に当該ユーザーの `categories` が 12 件生成される（`registrations_spec.rb` に追加）。

---

## 実装順序

```text
1. config/constants にカテゴリ定義（12件）
2. #23 migration（category_templates / categories / 3インデックス）+ データ投入マイグレーション（RED: schema/rollback 確認）
3. #24 モデル spec（RED）→ CategoryTemplate / Category 実装（belongs_to :user・バリデーション）→ Category.copy_templates_to（GREEN）
4. 登録フローにコピーを配線（RegistrationsController）+ spec（GREEN）
5. #25 request spec（RED）→ CategoriesController（index/new/create/edit/update/destroy・Current.user スコープ・初期削除拒否）+ ビュー（GREEN）
6. 全スイート + rubocop + brakeman → ruby/security レビュー → 分割コミット → PR（Closes #23 #24 #25）
```

---

## スコープ外（S3 では扱わない）

- `has_many :transactions` / `dependent: :nullify` / FK ON DELETE SET NULL → **S7**
- カテゴリの Turbo Stream 即時更新（#44）→ **S8**
- `merchant_classifications`（category_key を使う自動分類）→ **S5**
- #21 の「現金」PaymentMethod 自動生成 → **S4**

---

## 参考

- [ADR-0015 カテゴリ分類方針](0015-category-classification-strategy.md)
- [DATABASE_DESIGN.md](../design/DATABASE_DESIGN.md)（categories / category_templates 定義）
- [CATEGORY_CLASSIFICATION.md](../design/CATEGORY_CLASSIFICATION.md)
