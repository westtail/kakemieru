# ADR-0013: データモデル設計方針

- 日付: 2026-04-05
- ステータス: 決定済み（一部保留）

---

## コンテキスト

明細データの持ち方について、以下の観点で設計方針を決定する必要があった。

- 明細を期間（月）ごとにテーブルを分けるか、1テーブルにまとめるか
- `Card` モデルを挟むかどうか（`User → Transaction` vs `User → Card → Transaction`）
- 将来の集計・分析機能への対応

---

## 検討した選択肢

### 明細テーブルの持ち方

**A. 月ごとにテーブルを分ける**
- 各月のデータを独立したテーブルで管理
- デメリット：前年同月比・トレンド分析が JOIN だらけになる。テーブル数が増え続ける

**B. 全期間を1テーブルで管理（採用）**
- `transactions` テーブルに全明細を格納
- `effective_date` カラムで月・年を絞り込む（ADR-0017 で `date` → `effective_date` に変更）
- デメリット：データが増えるが、インデックスで対応可能

### Card モデルの有無

**A. User → Transaction（Card なし）**
- シンプルだが、カード別集計・ポイント管理・利用上限管理が難しくなる
- 後から Card を追加する場合、既存データのマイグレーションが必要

**B. User → Card → Transaction（Card あり・当時採用）**
- カード別集計が自然にできる
- 将来のポイント還元率・引き落とし口座・利用上限管理に対応しやすい
- `has_many :transactions, through: :cards` で `current_user.transactions` と直接辿れる

---

## 決定事項

### 1. 明細は全期間を1テーブルで管理

`transactions` テーブルに全明細を格納し、`effective_date` カラムで絞り込む。

> **⚠️ ADR-0017 で修正**: 集計・絞り込みは `date` ではなく `effective_date` を使う。
> `date` は原本として保持するが集計には使わない。

**理由**
- 月別・年別・カテゴリ別など、どの切り口でも自由に集計できる
- 前年同月比・支出トレンドなどの分析がシンプルなクエリで書ける
- 個人利用レベルのデータ量ではパフォーマンス問題は起きない
- `effective_date` カラムにインデックスを貼ることで絞り込みは十分高速

### 2. Card モデルを挟む（User → Card → Transaction）

**理由**
- 後から追加する場合の既存データマイグレーションが大変
- パフォーマンス・複雑性のデメリットはほぼない（JOIN が1段増えるだけ）
- 唯一のデメリット「アップロード時にカードを選ばせるUX」は工夫で解消できる
  - カードの事前登録＋デフォルト選択
  - 「前回と同じカード」の記憶
- 将来のポイント管理・引き落とし口座・利用上限管理で明確にメリットがある

> **⚠️ この決定は後の ADR で修正されている**
> - `Card` → `PaymentMethod` に改名（ADR-0016）
> - `transactions.user_id` を直接保持・`through: :cards` 廃止（ADR-0017 CRITICAL 2）
> - `Category` はコピー方式に変更・`category_templates` を別テーブルに切り出し（ADR-0017 CRITICAL 1）
>
> 現行のモデル構成は [DATABASE_DESIGN.md](../DATABASE_DESIGN.md) を参照。

### 3. モデル構成（当時の案 ※現行は ADR-0016/0017 で修正済み）

```
User
├─ has_many :cards
├─ has_many :transactions, through: :cards
└─ has_many :categories

Card
├─ belongs_to :user
└─ has_many :transactions

Category
└─ has_many :transactions

Transaction
├─ belongs_to :card
└─ belongs_to :category
```

---

## 保留事項 → すべて後続 ADR で解決済み

| 保留事項 | 解決した ADR |
|---|---|
| カテゴリをユーザーごとに持つか | ADR-0015・0017（コピー方式・category_templates 分離） |
| `amount` の型 | ADR-0017（integer・円単位） |
| デビットカード・電子マネー対応 | ADR-0016（payment_methods・フェーズ1対象外）|

---

## 結果

詳細なテーブル定義・クエリ例は [DATABASE_DESIGN.md](../DATABASE_DESIGN.md) を参照。
