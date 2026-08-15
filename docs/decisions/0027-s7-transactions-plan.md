# ADR-0027: S7 明細（transactions）の実装計画

- 日付: 2026-08-14
- ステータス: 提案中
- 関連: [ADR-0016 明細管理設計](0016-transaction-management-design.md) / [ADR-0017 DB設計クリティカル修正](0017-db-design-critical-fixes.md) / [ADR-0024 S3カテゴリ](0024-s3-categories-plan.md) / [ADR-0025 S4支払方法](0025-s4-payment-methods-plan.md) / [ADR-0026 S5取り込み](0026-s5-csv-import-plan.md)
- 対象 Issue: #40（migration）/ #38（モデル）/ #39（手動1件入力）

---

## コンテキスト

`transactions`（明細）はアプリの中核データ。**S6（CSV取り込み保存・手動まとめ入力）が Transaction レコードを作るため、S6 は S7 に依存する**（Issue 番号は S6<S7 だが実装依存は S7 が先）。S7 で「明細を1件書ける」ところまで作り、S6 の一括保存の土台にする。

S7 は、これまで各スライスで **transactions 未作成のため繰り延べていた関連の配線** をまとめて有効化する（下記）。

---

## テーブル設計（#40・決定）— PostgreSQL 16

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | NOT NULL / FK → users（マルチテナント直接保持） |
| payment_method_id | bigint | NOT NULL / 複合FK → payment_methods(user_id, id) |
| import_id | bigint | nullable / FK → imports（NULL = 手動入力） |
| category_id | bigint | nullable / 複合FK → categories(user_id, id)（NULL = 未分類） |
| date | date | NOT NULL・原本（不変） |
| amount | integer | NOT NULL・原本（円・不変） |
| description | string | nullable（CSV摘要原本。手動入力時は NULL） |
| merchant_name | string | NOT NULL・正規化店舗名（255・編集可） |
| amount_override | integer | nullable（訂正値・NULLなら原本） |
| date_override | date | nullable（訂正値・NULLなら原本） |
| effective_amount | integer | **GENERATED STORED** = COALESCE(amount_override, amount) |
| effective_date | date | **GENERATED STORED** = COALESCE(date_override, date) |
| deleted_at | datetime | ソフトデリート（NULL = 有効） |
| timestamps | | |

### GENERATED STORED カラム（決定）

Rails の `t.virtual ... stored: true` で作る（PG16 は生成カラム対応）。

```ruby
t.virtual :effective_amount, type: :integer, as: "COALESCE(amount_override, amount)", stored: true
t.virtual :effective_date,   type: :date,    as: "COALESCE(date_override, date)",     stored: true
```

集計・グラフ・月絞り込みは必ず effective_* を使う。

### インデックス（決定）

`deleted_at` を複合の2列目に置き `WHERE user_id=? AND deleted_at IS NULL` をインデックスで処理する（DATABASE_DESIGN）。

- `(user_id, deleted_at, effective_date)` … 月別絞り込み主クエリ
- `(user_id, deleted_at, category_id, effective_date)` … カテゴリ別集計
- `(user_id, deleted_at, payment_method_id)` … 支払方法別
- `(import_id)` … 取り込み単位操作
- `(user_id, merchant_name)` … キーワード前方一致

### 外部キー / ON DELETE（決定・単一列FL採用）

**方針決定（2026-08-14）**: 複合FK（`(user_id, category_id)` 等）は Rails の `schema.rb`（Ruby 形式）で表現できずダンプ時に消える。structure.sql への切替は影響が大きいため、**S7 では単一列FK + アプリ層スコープ**とし、DB 層の複合FK（多層防御）は structure.sql 導入とセットで別途フォローアップ（Issue 化）する。

単一列FKなので ON DELETE は Rails の `foreign_key: { on_delete: ... }` で schema.rb に表現できる:

- `category_id → categories(id)` … `on_delete: :nullify`（カテゴリ削除で category_id を NULL=未分類化）。
- `payment_method_id → payment_methods(id)` … 既定（NO ACTION≈RESTRICT）。物理削除は PaymentMethod の `before_destroy`（明細あり→アーカイブ）で先に回避。
- `import_id → imports(id)` … 既定（RESTRICT）。取り消しは transactions のソフトデリート。
- `user_id → users(id)` … 既定。退会カスケードは Rails の `dependent: :destroy`（横断課題 #110 と整合）。

**テナント整合（category/payment_method が同一ユーザーか）はアプリ層で担保**: コントローラのセレクトを `Current.user` スコープで生成し、strong params 経由の他ユーザー ID 混入を防ぐ。DB 層の複合FKによる多層防御はフォローアップに委ねる。

生成カラム（`t.virtual ... stored: true`）は schema.rb で表現可能。マイグレーションは `def change` で可逆。

---

## S7 で有効化する繰り延べ関連（決定）

transactions ができたことで、各スライスで保留していた配線を追加する。

- **Transaction**（#38）: `belongs_to :user` / `belongs_to :payment_method` / `belongs_to :import, optional: true` / `belongs_to :category, optional: true`
- **User**: `has_many :transactions, dependent: :destroy`
- **PaymentMethod**: `has_many :transactions`。**S4 で繰り延べた「明細あり→アーカイブ」`before_destroy` を実装**（`transactions.exists?` なら `update!(archived_at: Time.current)` + `throw :abort`）。→ S4 の物理削除ロジックがここで完成。
- **Category**: `has_many :transactions, dependent: :nullify`（S3 で繰り延べた nullify を実装）。DB の SET NULL と二層で未分類化。
- **Import**: `has_many :transactions, dependent: :restrict_with_exception`（S5 で繰り延べ。取り消しは transactions のソフトデリートで行う＝物理削除させない）

---

## モデル設計（#38・決定）— `app/models/transaction.rb`

- バリデーション: `user_id` / `payment_method_id` / `amount` / `merchant_name` 必須（`date` も必須）
- `scope :not_deleted, -> { where(deleted_at: nil) }`
- `scope :in_month, ->(year, month) { ... }`（**effective_date で月初〜月末**。`Date.new(year, month, 1)` 〜 翌月初 未満）
- `belongs_to :import/:category` は optional
- テナント整合バリデーション（category / payment_method が同じ user か）は DB 複合FKで担保されるが、分かりやすいエラーのためモデルにも軽く入れるか検討（複合FK があるので必須ではない）
- effective_amount / effective_date は**読み取り専用**（generated。Rails からは書かない）

FactoryBot: `spec/factories/transactions.rb`。

---

## 手動1件入力（#39・決定）— `TransactionsController`

- `GET /transactions/new` … 日付・金額・店舗名・カテゴリ（任意=未分類）・支払方法のフォーム
- `POST /transactions` … `Current.user.transactions.new(...)`。`import_id = NULL`（手動）。`date`/`amount` に入力値を直接、override は NULL
- strong params は `date, amount, merchant_name, category_id, payment_method_id` のみ（user_id/override/effective_* は不可）
- category_id / payment_method_id は `Current.user` のものだけ選べる（セレクトを current_user スコープで生成）+ 複合FKで DB 担保
- 保存後 `/transactions?month=YYYY-MM` へリダイレクト（一覧は S8 だが遷移先だけ用意。当面は暫定表示 or 最小 index）
- 一覧（index）は S8（#43）。S7 では new/create を中心にし、リダイレクト先の最小 index を用意するか、S8 まで new/create のみに絞るかは実装時に決める（**#39 の受入は new/create + リダイレクト**）

---

## テスト方針（TDD）

- **#40 migration**: migrate / rollback / redo。生成カラムの整合（`effective_amount = COALESCE(amount_override, amount)`）を実データで確認。複合FKで他ユーザーの category/payment_method を弾くこと。
- **#38 モデル spec**: 必須バリデーション、`not_deleted`、`in_month`（月初・月末の境界値）、override 時に effective_* が切り替わること、category 削除で category_id が NULL 化（nullify）、import ありの Import 物理削除が restrict されること、PaymentMethod の明細あり→アーカイブ。
- **#39 リクエスト spec**: 手動入力で `import_id=NULL` の Transaction 生成、未ログイン、他ユーザーの category/payment_method を弾く、バリデーションエラー再描画、保存後リダイレクト。

---

## 実装順序（TDD）

1. ADR + ブランチ（本コミット）
2. #40 migration（テーブル + 生成カラム + 複合FK + 5インデックス）→ 可逆性・生成カラム整合確認
3. #38 Transaction spec(RED) → モデル + 各既存モデルの繰り延べ関連配線(GREEN)
4. #39 request spec(RED) → TransactionsController + フォーム + routes(GREEN)
5. 全スイート + rubocop + brakeman → ruby/security レビュー → 分割コミット → PR

---

## スコープ外（S7 では扱わない）

- 明細一覧・絞り込み・編集（#41/#43/#44）→ **S8**
- CSV取り込み保存・手動まとめ入力（Import + Transaction 一括）→ **S6**（S7 完了後）
- 取り込み取り消し・サマリーAPI → **S9**
- ダッシュボード（グラフ）→ **S10**

---

## 未決・確認したい点

- **開発環境**: develop が Rails 8.1.3.1（dependabot）に更新され、ローカルコンテナの gem が旧版。`bundle install`（またはイメージ再ビルド）が必要。実装・テスト前に解消する。
- 複合FK・生成カラムは Rails 8.1 / PG16 で `t.virtual` + `execute` により実装するが、rollback の書き方（`def up/down`）を実装時に検証する。
