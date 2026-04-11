# データベース設計

最終更新: 2026-04-08

---

## 設計方針

- 明細は期間ごとに分けず全部 `transactions` テーブルに格納する
- 「1ヶ月の明細」はクエリの `effective_date` 絞り込みで表現（テーブル分割しない）
- 集計・グラフ・レポートは全て `effective_date` / `effective_amount` を使う（`date` / `amount` は原本保持のみ）
- `transactions.user_id` を直接持つことでマルチテナント分離をDB側で保証
- `WHERE user_id = current_user.id` だけで安全に絞り込める

**テーブル分割しない理由**
- 月ごとにテーブルを分けると前年同月比・トレンド分析が JOIN だらけになる
- `effective_date` カラムにインデックスを貼れば絞り込みのパフォーマンスは十分
- 個人利用レベルのデータ量ではパフォーマンス問題は起きない

---

## モデル構成

```
User
├─ has_many :payment_methods
├─ has_many :transactions        # user_id を直接持つ
├─ has_many :imports
└─ has_many :categories

PaymentMethod（支払い手段: クレカ・QR・現金など）
├─ belongs_to :user
├─ has_many :transactions
└─ has_many :imports

Import（CSV取り込み履歴）
├─ belongs_to :user
├─ belongs_to :payment_method
└─ has_many :transactions

CategoryTemplate（システム共通テンプレート・不変）
└─ 登録時に categories にコピーされる

Category（ユーザーごとのカテゴリ・コピー方式）
├─ belongs_to :user              # 必ず user_id あり（NOT NULL）
└─ has_many :transactions

Transaction（明細）
├─ belongs_to :user              # 直接持つ（マルチテナント保証）
├─ belongs_to :payment_method
├─ belongs_to :import, optional: true   # NULL = 手動入力
└─ belongs_to :category, optional: true # NULL = 未分類
```

---

## テーブル定義

### users

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| email | string | メールアドレス |
| password_digest | string | bcrypt ハッシュ |
| admin | boolean | 管理者フラグ（default: false） |
| created_at | datetime | |
| updated_at | datetime | |

### category_templates

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| category_key | string | 分類キー（"food" / "transport" など） |
| name | string | デフォルト表示名（"食費" / "交通費" など） |
| created_at | datetime | |
| updated_at | datetime | |

- システム管理・ユーザーは編集不可
- 新規ユーザー登録時に `categories` にコピーされる
- `category_key` は `merchant_classifications` との紐づけに使用

### payment_methods

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users |
| name | string | 名称（例: "楽天カード" / "PayPay" / "現金"） |
| payment_type | string | 種別（credit / debit / e_money / qr / cash） |
| archived_at | datetime | ソフトデリート（NULL = 使用中） |
| created_at | datetime | |
| updated_at | datetime | |

**payment_type の値**（Rails `enum` + CHECK 制約で保護）
- `credit`：クレジットカード
- `debit`：デビットカード
- `e_money`：電子マネー（Suicaなど）
- `qr`：QRコード決済（PayPay・楽天Payなど）
- `cash`：現金

```ruby
# モデル定義例
enum :payment_type, { credit: "credit", debit: "debit", e_money: "e_money", qr: "qr", cash: "cash" }
validates :payment_type, presence: true
```

**初期生成**
- ユーザー登録時に `payment_type: cash`（現金）を1件自動生成する
- 手動入力時に「現金という支払方法を先に作ってください」というUXを避けるため
- `category_templates → categories` のコピー方式と同じ発想

**削除ポリシー**（明細の有無で動作を分ける）

| 条件 | 動作 |
|---|---|
| 明細ゼロの支払方法を削除 | 物理削除（誤登録の整理を想定） |
| 明細ありの支払方法を削除 | `archived_at` をセット（永続アーカイブ） |
| ユーザー退会 | users の CASCADE 削除で全削除（アーカイブ済みも含む） |

- アーカイブ済みは新規取り込み・手動入力のセレクトには表示しない
- アーカイブ済みでも過去明細の参照・集計には引き続き使用される（`payment_method_id` FK は有効のまま）
- 復元ボタンで `archived_at` を NULL に戻せる
- アーカイブ時は「過去の明細はそのまま残り、新しい取り込みや手動入力では選択できなくなります」と説明を表示する

### imports

1回の取り込み操作をまとめる単位。CSV・OCR・API連携など入力経路に関わらず、複数の Transaction を1つの操作として管理する。

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users |
| payment_method_id | bigint | FK → payment_methods |
| source_type | string | 取り込み経路（csv / ocr / api / manual_bulk）フェーズ1は csv 固定 |
| source_ref | string | 取り込み元の参照情報（source_type に応じて意味が変わる。csv: ファイル名、ocr: 画像ファイル名、api: エンドポイント識別子、manual_bulk: NULL） |
| file_hash | string | 重複防止用ハッシュ（csv の場合はファイルの SHA256。その他の source_type では使用方法を別途定義） |
| row_count | integer | 取り込み件数 |
| imported_at | datetime | 取り込み日時 |
| created_at | datetime | |
| updated_at | datetime | |

**source_type の値**（Rails `enum` + CHECK 制約で保護）
- `csv`：CSV ファイルの取り込み（フェーズ1で使用）
- `ocr`：レシート画像の OCR 取り込み（フェーズ4以降）
- `api`：銀行・決済サービスの API 連携（フェーズ4以降）
- `manual_bulk`：複数件の手動一括入力（将来拡張候補）

```ruby
# モデル定義例
enum :source_type, { csv: "csv", ocr: "ocr", api: "api", manual_bulk: "manual_bulk" }
validates :source_type, presence: true
```

**`import_id` の意味（Transaction 側）**
- `import_id あり`：何らかの取り込み操作由来
- `import_id = NULL`：ユーザーによる手動1件入力

**インデックス**
- `[user_id, file_hash]`（重複チェック用）

### categories

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users（NOT NULL・必ずユーザーに紐づく） |
| category_key | string | テンプレートとの紐づけキー（独自カテゴリは NULL） |
| name | string | カテゴリ名（ユーザーが自由に変更可） |
| created_at | datetime | |
| updated_at | datetime | |

**「未分類」カテゴリの扱い**
- `transactions.category_id = NULL` が未分類を表す（専用カテゴリレコードは持たない）
- `category_templates` には `category_key: "uncategorized"` を持たせ、ユーザー登録時に `categories` へコピーする
- コピーされた「未分類」カテゴリは名前変更のみ可・削除不可（`category_key` が "uncategorized" のものは保護）
- カテゴリ削除時に `SET NULL` されると `category_id = NULL`（= 未分類）に戻る

**インデックス**
- `UNIQUE (user_id, name)`
- `UNIQUE (user_id, category_key)` WHERE category_key IS NOT NULL

### transactions

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users（直接保持・マルチテナント保証） |
| payment_method_id | bigint | FK → payment_methods |
| import_id | bigint | FK → imports（nullable: NULL = 手動入力） |
| category_id | bigint | FK → categories（nullable: NULL = 未分類） |
| date | date | 利用日（原本・不変） |
| amount | integer | 請求金額・円（原本・不変） |
| description | string | CSV原本の摘要欄テキスト（不変）。手動入力時は NULL。merchant_name の正規化元として使用 |
| merchant_name | string | 正規化した店舗名（ユーザー編集可能・分類キー） |
| amount_override | integer | 金額の訂正値（NULL なら原本を使用） |
| date_override | date | 日付の訂正値（NULL なら原本を使用） |
| effective_amount | integer | 集計用金額（generated: COALESCE(amount_override, amount)） |
| effective_date | date | 集計用日付（generated: COALESCE(date_override, date)） |
| deleted_at | datetime | ソフトデリート（NULL = 有効） |
| created_at | datetime | |
| updated_at | datetime | |

**カラムの役割**
- `date` / `amount` / `description`：CSV原本。取り込み後は変更しない（手動入力の場合、description は NULL）
- `merchant_name`：自動生成 → ユーザー編集可。分類キーとして使用
- `amount_override` / `date_override`：訂正が必要な場合のみ入れる
- `effective_amount` / `effective_date`：集計・グラフは必ずこちらを使う（DB生成カラム）
- `import_id = NULL`：手動入力（現金・QRなど）
- `user_id`：直接保持でマルチテナント分離を保証

**インデックス**
- `user_id`（マルチテナント絞り込み用）
- `(user_id, effective_date)`（月別集計用・複合）
- `(user_id, category_id, effective_date)`（カテゴリ別集計用・複合）
- `(user_id, payment_method_id)`（支払方法別絞り込み用・複合）
- `import_id`（取り込み単位の操作用）
- `(user_id, merchant_name)`（キーワード検索用・複合 LIKE 検索に使用）
- `deleted_at`（有効明細の絞り込み用）

**ON DELETE ポリシー**
- `users` 削除 → CASCADE（退会時に全データ削除）
- `payment_methods` 削除 → RESTRICT（archived_at によるソフトデリートで対応・物理削除は起きない）
- `imports` 削除 → RESTRICT（Import を物理削除させない。取り込み取り消しは transactions.deleted_at でソフトデリート）
- `categories` 削除 → SET NULL（カテゴリ削除時に transactions.category_id を NULL にする = 未分類扱い）

---

## クエリ例

### 1ヶ月の明細を取得

```ruby
# Transaction に scope を定義
class Transaction < ApplicationRecord
  scope :in_month, ->(year, month) {
    where(effective_date: Date.new(year, month).all_month)  # 集計は effective_date を使う
      .where(deleted_at: nil)
  }
end

# 使う時
current_user.transactions.in_month(2026, 1)
```

### カテゴリ別集計

```ruby
current_user.transactions
  .in_month(2026, 1)
  .joins(:category)
  .group("categories.name")
  .sum(:effective_amount)
```

### 前年同月比

```ruby
this_year  = current_user.transactions.in_month(2026, 1).sum(:effective_amount)
last_year  = current_user.transactions.in_month(2025, 1).sum(:effective_amount)
diff = this_year - last_year
```

---

## 将来の拡張カラム候補

フェーズ2以降で追加予定：

### payment_methods テーブル
- `point_rate`（decimal）：ポイント還元率
- `limit_amount`（integer）：利用上限
- `bank_account`（string）：引き落とし口座

### transactions テーブル
- `is_installment`（boolean）：分割払いフラグ
- `installment_count`（integer）：分割回数

### monthly_budgets テーブル
- `memo`（text）：月単位のメモ（「今月は旅行で食費多め」など振り返り用）

### imports テーブル（将来）
- レシート画像・OCR取り込み対応（`source_type`: csv / image / manual）

---

---

## 決定事項の追記（2026-04-07）

### `amount` の型：integer（円単位）

クレジットカード明細は円単位のため小数不要。集計・比較演算がシンプルになる。

### デビットカード・電子マネー：フェーズ1対象外

---

## フェーズ2: 予算・持ち越しモデル

### 設計方針

| モデル | 役割 |
|--------|------|
| `BudgetTemplate` | 「2026年版」など名前付きの予算設定。年単位でバージョン管理 |
| `BudgetItem` | テンプレート × カテゴリ × 基本予算額 |
| `MonthlyBudget` | ある月にどのテンプレートを適用したかの記録 |
| `Carryover` | 月末確定ボタンで生成。カテゴリ別の差分（余剰/超過）を保存 |

有効予算 = `BudgetItem.amount` + `Carryover.amount`（前月から持ち越し）

### 持ち越しの確定フロー

```
月末
→ 差分確認（有効予算 - 実績 をカテゴリ別に表示）
→「差分を翌月へ持ち越す」確定ボタン
→ Carryover レコード保存
→ MonthlyBudget.confirmed_at に日時を記録
```

### 未確定月の暫定表示

前月の Carryover が存在しない場合、リアルタイム計算した暫定値を「※暫定」バッジ付きで表示。前月が確定されると自動的に固定値に切り替わる。

### モデル全体構成（フェーズ1＋2）

```
User
├─ has_many :payment_methods
├─ has_many :transactions                      # user_id 直接保持
├─ has_many :imports
├─ has_many :categories                        # user_id NOT NULL（コピー方式）
├─ has_many :budget_templates
└─ has_many :monthly_budgets

CategoryTemplate                               # システム共通テンプレート・不変
                                               # 登録時に categories にコピーされる

PaymentMethod
├─ belongs_to :user
├─ has_many :transactions
└─ has_many :imports

Category
├─ belongs_to :user                            # NOT NULL・必ずユーザーに紐づく
└─ has_many :transactions

Transaction
├─ belongs_to :user                            # 直接保持（マルチテナント保証）
├─ belongs_to :payment_method
├─ belongs_to :import, optional: true
└─ belongs_to :category, optional: true

BudgetTemplate
├─ belongs_to :user
├─ name: string                                # "2026年版" など
├─ valid_from: date
├─ valid_to: date（null = 無期限）
└─ has_many :budget_items

BudgetItem
├─ belongs_to :budget_template
├─ belongs_to :category
└─ amount: integer

MonthlyBudget
├─ belongs_to :user
├─ belongs_to :budget_template
├─ year_month: date                            # 月初日で保存（例: 2026-04-01）
├─ confirmed_at: datetime（null = 未確定）
└─ has_many :carryovers

Carryover
├─ belongs_to :monthly_budget
├─ belongs_to :category
└─ amount: integer                             # 正 = 余剰、負 = 超過
```

### テーブル定義

#### budget_templates

| カラム | 型 | 説明 |
|--------|----|----|
| id | bigint | PK |
| user_id | bigint | FK → users |
| name | string | テンプレート名（"2026年版" など） |
| valid_from | date | 適用開始年月 |
| valid_to | date | 適用終了年月（null = 無期限） |
| created_at | datetime | |
| updated_at | datetime | |

#### budget_items

| カラム | 型 | 説明 |
|--------|----|----|
| id | bigint | PK |
| budget_template_id | bigint | FK → budget_templates |
| category_id | bigint | FK → categories |
| amount | integer | 基本予算額（円） |
| created_at | datetime | |
| updated_at | datetime | |

#### monthly_budgets

| カラム | 型 | 説明 |
|--------|----|----|
| id | bigint | PK |
| user_id | bigint | FK → users |
| budget_template_id | bigint | FK → budget_templates |
| year_month | date | 対象年月（月初日で保存: 2026-04-01。DATE 型で範囲クエリ・ソートを自然に行う） |
| confirmed_at | datetime | 持ち越し確定日時（null = 未確定） |
| created_at | datetime | |
| updated_at | datetime | |

**インデックス**
- `[user_id, year_month]`（ユニーク）

#### carryovers

| カラム | 型 | 説明 |
|--------|----|----|
| id | bigint | PK |
| monthly_budget_id | bigint | FK → monthly_budgets |
| category_id | bigint | FK → categories |
| amount | integer | 持ち越し金額（正 = 余剰、負 = 超過） |
| created_at | datetime | |
| updated_at | datetime | |

### クエリ例

#### 4月の有効予算（カテゴリ別）

```ruby
# テンプレートの基本予算
base = monthly_budget.budget_template.budget_items
                     .group(:category_id).sum(:amount)

# 3月からの持ち越し
prev_month = MonthlyBudget.find_by(user: current_user, year_month: Date.new(2026, 3, 1))
carryover  = prev_month&.carryovers&.group(:category_id)&.sum(:amount) || {}

# 有効予算 = 基本予算 + 持ち越し
effective = base.merge(carryover) { |_k, b, c| b + c }
```

#### 実績との差分

```ruby
actual = current_user.transactions
                     .in_month(2026, 4)
                     .group(:category_id).sum(:effective_amount)

diff = effective.merge(actual) { |_k, e, a| e - a }
```
