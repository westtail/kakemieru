# データベース設計

最終更新: 2026-04-05

---

## 設計方針

- 明細は期間ごとに分けず全部 `transactions` テーブルに格納する
- 「1ヶ月の明細」はクエリの `date` 絞り込みで表現（テーブル分割しない）
- `User → Card → Transaction` の経路で辿ることで「誰のデータか」を保証
- `has_many :transactions, through: :cards` で `current_user.transactions` と直接辿れる

**テーブル分割しない理由**
- 月ごとにテーブルを分けると前年同月比・トレンド分析が JOIN だらけになる
- `date` カラムにインデックスを貼れば絞り込みのパフォーマンスは十分
- 個人利用レベルのデータ量ではパフォーマンス問題は起きない

---

## モデル構成

```
User
├─ has_many :cards
├─ has_many :transactions, through: :cards
└─ has_many :categories

Card（クレジットカード・電子マネーなど支払い手段）
├─ belongs_to :user
└─ has_many :transactions

Category（カテゴリ）
└─ has_many :transactions

Transaction（明細）
├─ belongs_to :card
└─ belongs_to :category
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

### cards

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users |
| name | string | カード名（例: "楽天カード"） |
| card_type | string | 種別（credit / debit / e-money） |
| created_at | datetime | |
| updated_at | datetime | |

**card_type の値**
- `credit`：クレジットカード
- `debit`：デビットカード
- `e_money`：電子マネー（Suica・PayPayなど）

### categories

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users（ユーザーごとのカスタムカテゴリ） |
| name | string | カテゴリ名（例: "食費"） |
| created_at | datetime | |
| updated_at | datetime | |

### transactions

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| card_id | bigint | FK → cards |
| category_id | bigint | FK → categories（nullable: 未分類の場合 null） |
| date | date | 利用日 |
| amount | integer | 請求金額（円） |
| description | string | 店舗名・説明文 |
| created_at | datetime | |
| updated_at | datetime | |

**インデックス**
- `card_id`（belongs_to で自動）
- `category_id`（belongs_to で自動）
- `date`（月別絞り込みに使用）

---

## クエリ例

### 1ヶ月の明細を取得

```ruby
# Transaction に scope を定義
class Transaction < ApplicationRecord
  scope :in_month, ->(year, month) {
    where(date: Date.new(year, month).all_month)
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
  .sum(:amount)
```

### 前年同月比

```ruby
this_year  = current_user.transactions.in_month(2026, 1).sum(:amount)
last_year  = current_user.transactions.in_month(2025, 1).sum(:amount)
diff = this_year - last_year
```

---

## 将来の拡張カラム候補

フェーズ2以降で追加予定：

### cards テーブル
- `point_rate`（decimal）：ポイント還元率
- `limit_amount`（integer）：利用上限
- `bank_account`（string）：引き落とし口座

### transactions テーブル
- `is_installment`（boolean）：分割払いフラグ
- `installment_count`（integer）：分割回数
- `original_amount`（integer）：利用金額（請求金額と別の場合）
- `file_hash`（string）：重複防止用ファイルハッシュ

---

---

## 決定事項の追記（2026-04-07）

### カテゴリ設計：1テーブルで共通＋ユーザー独自を併用

`user_id: null` をシステム共通、`user_id: あり` をユーザー独自として1テーブルで管理。

```ruby
Category.where(user_id: [nil, current_user.id])
```

- 共通カテゴリ（食費・交通費・娯楽・家賃・光熱費・通信費など）はシードで投入
- ユーザーが独自カテゴリを追加・編集・削除できる
- 共通カテゴリはユーザーが編集不可

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
├─ has_many :cards
├─ has_many :transactions, through: :cards
├─ has_many :categories                        # user_idあり = 独自カテゴリ
├─ has_many :budget_templates
└─ has_many :monthly_budgets

Card
├─ belongs_to :user
└─ has_many :transactions

Category
├─ belongs_to :user, optional: true            # null = 共通カテゴリ
└─ has_many :transactions

Transaction
├─ belongs_to :card
└─ belongs_to :category

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
├─ year_month: string                          # "2026-04"
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
| year_month | string | 対象年月（"2026-04"） |
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
prev_month = MonthlyBudget.find_by(user: current_user, year_month: "2026-03")
carryover  = prev_month&.carryovers&.group(:category_id)&.sum(:amount) || {}

# 有効予算 = 基本予算 + 持ち越し
effective = base.merge(carryover) { |_k, b, c| b + c }
```

#### 実績との差分

```ruby
actual = current_user.transactions
                     .in_month(2026, 4)
                     .group(:category_id).sum(:amount)

diff = effective.merge(actual) { |_k, e, a| e - a }
```
