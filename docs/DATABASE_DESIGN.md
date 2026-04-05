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

## 未検討事項

- [ ] カテゴリをユーザーごとに持つか・システム共通で持つか（現状はユーザーごと）
- [ ] `amount` の型：integer（円単位）か decimal（小数対応）か
- [ ] デビットカード・電子マネーの明細フォーマット対応
