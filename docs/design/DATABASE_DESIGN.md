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

**初期データ（`db/seeds.rb` で投入）**

| category_key | name |
|---|---|
| `food` | 食費 |
| `dining_out` | 外食 |
| `transport` | 交通費 |
| `daily` | 日用品 |
| `entertainment` | 娯楽 |
| `clothing` | 衣服・美容 |
| `medical` | 医療・健康 |
| `utilities` | 光熱費 |
| `communication` | 通信費 |
| `subscription` | サブスク |
| `education` | 教育 |
| `other` | その他 |

### payment_methods

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users |
| name | string | 名称（例: "楽天カード" / "PayPay" / "現金"） |
| payment_type | string | 種別（credit / debit / e_money / qr / cash） |
| archived_at | datetime | ソフトデリート（NULL = 使用中）。datetime 精度で記録し、復元時の監査ログに活用 |
| created_at | datetime | |
| updated_at | datetime | |

**payment_type の値**（Rails `enum` + CHECK 制約で保護）
- `credit`：クレジットカード
- `debit`：デビットカード
- `e_money`：電子マネー（Suicaなど）
- `qr`：QRコード決済（PayPay・楽天Payなど）
- `cash`：現金

```ruby
# モデル定義例（実装時は config/constants/ に定数を一元管理すること）
enum :payment_type, { credit: "credit", debit: "debit", e_money: "e_money", qr: "qr", cash: "cash" }
validates :payment_type, presence: true
```

**初期生成**
- ユーザー登録時に `payment_type: cash`（現金）を1件自動生成する
- 手動入力時に「現金という支払方法を先に作ってください」というUXを避けるため
- `category_templates → categories` のコピー方式と同じ発想

**インデックス**
- `archived_at`（アクティブな支払方法の絞り込み `WHERE archived_at IS NULL` 用）

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
validates :source_ref, presence: true, unless: -> { source_type == "manual_bulk" }
# source_ref はファイル名相当。パストラバーサル防止のためアプリ層でサニタイズ必須
```

**`import_id` の意味（Transaction 側）**
- `import_id あり`：何らかの取り込み操作由来
- `import_id = NULL`：ユーザーによる手動1件入力

**インデックス**
- `[user_id, file_hash]`（UNIQUE 制約。重複取り込み防止）

**file_hash の一意判定スコープ**
- スコープは **`user_id + file_hash`**。異なるユーザーが同内容の CSV を取り込んでも別レコードとして扱う
- `payment_method_id` はスコープに含めない。同一ファイルを別の支払方法で取り込むことは業務上発生しないため、より厳しい `user_id + file_hash` で防ぐ
- ソフトデリート（`deleted_at` が NULL でないレコード）も UNIQUE 制約の対象に含まれる。取り消し後の同ファイル再取り込みは不可（管理画面で Import を物理削除しない限り再取り込みできない）

### merchant_classifications

店舗名とカテゴリキーのマッピングキャッシュ。フェーズ1ではテーブルのみ作成・中身は空。フェーズ2でバッチ AI 分類を実装する（ADR-0015 参照）。

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| merchant_name | string | 店舗名（CSV の表記そのまま） |
| category_key | string | カテゴリキー（categories.category_key と対応） |
| source | string | マッピング元（`ai` / `user_manual`） |
| classified_at | datetime | 分類日時 |
| created_at | datetime | |
| updated_at | datetime | |

**`source` の値**
- `ai`：バッチ処理で AI が自動分類（フェーズ2以降）
- `user_manual`：ユーザーが手動で修正 → AI は上書きしない

**インデックス**
- `UNIQUE (merchant_name)`
- `category_key`

### categories

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | FK → users（NOT NULL・必ずユーザーに紐づく） |
| category_key | string | テンプレートとの紐づけキー（独自カテゴリは NULL） |
| name | string | カテゴリ名（ユーザーが自由に変更可） |
| created_at | datetime | |
| updated_at | datetime | |

**「未分類」の扱い**
- `transactions.category_id = NULL` が未分類を表す
- 専用の「未分類」カテゴリレコードは持たない（`category_templates` にも `uncategorized` は含めない）
- カテゴリ削除時に `SET NULL` されると `category_id = NULL`（= 未分類）に自然に戻る
- UI のカテゴリセレクトには「未分類」を先頭の特殊オプション（value 空）として表示し、選択時に `category_id = NULL` をセットする

**インデックス**
- `UNIQUE (user_id, name)`
- `UNIQUE (user_id, category_key)` WHERE category_key IS NOT NULL
- `UNIQUE (user_id, id)`（transactions の複合FK `(user_id, category_id) REFERENCES categories(user_id, id)` の参照先として必要）

**category_templates のインデックス**
- `UNIQUE (category_key)`（テンプレートキーの重複登録を防ぐ）

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
- `date` / `amount`：原本。CSV取り込み時はCSVの値、手動入力時はユーザー入力値をそのまま格納
- `description`：CSV原本の摘要テキスト。手動入力時は NULL
- `merchant_name`：自動生成（description または店舗名から正規化） → ユーザー編集可。最大 255文字。全角→半角・前後スペース除去のみ行い、それ以上の正規化はアプリ層に委ねる
- `amount_override` / `date_override`：訂正が必要な場合のみ入れる（NULL = 原本を使用）
- `effective_amount` / `effective_date`：集計・グラフは必ずこちらを使う（DB生成カラム）
- `import_id = NULL`：手動1件入力（現金・QRなど）
- `user_id`：直接保持でマルチテナント分離を保証

**手動入力時の date / amount の扱い**
- 手動1件入力（`/transactions/new`）では、ユーザーが入力した日付・金額を `date` / `amount` に直接格納する
- `date_override` / `amount_override` は NULL のまま（原本 = 入力値）
- `import_id = NULL` でCSV由来でないことを示す

**インデックス**
- `(user_id, deleted_at, effective_date)`（月別絞り込み + 有効明細フィルタ・主クエリ用）
- `(user_id, deleted_at, category_id, effective_date)`（カテゴリ別集計用）
- `(user_id, deleted_at, payment_method_id)`（支払方法別絞り込み用）
- `import_id`（取り込み単位の操作用）
- `(user_id, merchant_name)`（キーワード検索用・前方一致 LIKE に有効）

> **注**: `deleted_at` を複合インデックスの2列目に置くことで `WHERE user_id = ? AND deleted_at IS NULL` の絞り込みをインデックスで処理できる。`deleted_at` 単独インデックスは削除。

**ON DELETE ポリシー**
- `users` 削除 → CASCADE（退会時に全データ削除）
- `payment_methods` 削除 → RESTRICT（物理削除はアプリ層で制御。明細ゼロなら物理削除・明細ありなら archived_at のみセット）
- `imports` 削除 → RESTRICT（Import を物理削除させない。取り込み取り消しは transactions.deleted_at でソフトデリート）
- `categories` 削除 → SET NULL（カテゴリ削除時に transactions.category_id を NULL にする = 未分類扱い）

**payment_methods 削除の実装方針（アプリ層）**

```ruby
class PaymentMethod < ApplicationRecord
  before_destroy do
    if transactions.exists?
      update!(archived_at: Time.current)
      throw :abort  # 物理削除を中断してアーカイブに切り替え
    end
    # transactions がなければ物理削除に進む
  end
end
```

**複合FK（user_id + category_id）**

`transactions.(user_id, category_id)` に複合 FK を貼り、他ユーザーのカテゴリへの誤紐づけを DB 層で防ぐ。

```sql
ALTER TABLE transactions
  ADD CONSTRAINT fk_tx_user_category
  FOREIGN KEY (user_id, category_id) REFERENCES categories(user_id, id);
```

- フェーズ1から採用（マルチテナント分離の多層保護）
- categories テーブルに `UNIQUE (user_id, id)` が必要（Rails は主キーのみ参照するため、複合UNIQUEを追加）

**generated column のテスト要件**

`effective_amount` / `effective_date` はマイグレーション追加時に以下を確認する。

```sql
-- 既存レコードとの整合性チェック
SELECT COUNT(*) FROM transactions
WHERE effective_amount <> COALESCE(amount_override, amount)
   OR effective_date   <> COALESCE(date_override, date);
-- → 0 件であること
```

- migration 実行後、staging で上記 SQL を必ず実行してから本番適用する

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
- レシート画像・OCR取り込み対応（`source_type`: `ocr` を使用。既存 enum 値 `csv / ocr / api / manual_bulk` と整合）

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

**インデックス**
- `UNIQUE (budget_template_id, category_id)`（同テンプレート内で同カテゴリの重複登録を防ぐ）

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
- `UNIQUE (user_id, year_month)`

**`confirmed_at` の状態遷移**

```
NULL（未確定）
  ↓ 「差分を翌月へ持ち越す」ボタンを押す
  ↓ Carryover レコードを生成
datetime（確定済み）
  ↓ ※確定後は原則変更不可
  ↓ （管理機能で取り消す場合のみ NULL に戻す）
NULL（再開放）
```

- `confirmed_at = NULL`：当月はまだ確定されていない。暫定値（リアルタイム計算）を「※暫定」バッジ付きで表示
- `confirmed_at != NULL`：確定済み。Carryover レコードが存在し、翌月の有効予算に反映されている
- 確定後に明細を追加・編集した場合、確定値は変わらない（再確定は管理画面の操作が必要）

**冪等性の保証（実装要件）**

- 確定処理のエントリポイントで `confirmed_at != NULL` を確認し、セット済みなら noop で 200 を返す
- Carryover の生成と `confirmed_at` のセットは **1トランザクション** で実行する
- `carryovers` の `UNIQUE (monthly_budget_id, category_id)` が多重 INSERT に対する DB レベルの二重防衛となる
- UI は `confirmed_at != NULL` のとき確定ボタンを disabled にし、フォーム再送信を防止する

#### carryovers

| カラム | 型 | 説明 |
|--------|----|----|
| id | bigint | PK |
| monthly_budget_id | bigint | FK → monthly_budgets |
| category_id | bigint | FK → categories |
| amount | integer | 持ち越し金額（正 = 余剰、負 = 超過） |
| created_at | datetime | |
| updated_at | datetime | |

**インデックス**
- `UNIQUE (monthly_budget_id, category_id)`（同月・同カテゴリの持ち越しレコードの重複登録を防ぐ）

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
