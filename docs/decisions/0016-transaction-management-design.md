# ADR-0016: 明細管理・支払い手段設計

- 日付: 2026-04-08
- ステータス: 決定済み

---

## コンテキスト

明細の削除・編集・手動入力・取り込み履歴について設計方針を決定する必要があった。
また、クレジットカード以外の支払い手段（QR決済・現金など）への対応方針も検討した。

---

## 検討した選択肢

### 明細の原本保持方法

**A. 1テーブルで原本と編集値を同居（採用）**
- `description` / `amount` / `date` を原本として不変に保つ
- `amount_override` / `date_override` で上書き値を別カラムに持つ
- シンプルで JOIN が不要

**B. 2テーブルで原本と整形データを分離**
- 原本テーブルと作業テーブルを分ける
- テーブルが増えて複雑になる

### 取り込み履歴

**A. 履歴なし（1テーブルのみ）**
- シンプルだが取り込みミス時に日付範囲でしか削除できない
- 手動入力と CSV 由来の区別ができない

**B. imports テーブルを別途持つ（採用）**
- 1ファイル1レコードで軽い
- `import_id` で CSV 由来の明細をまるごと取り消せる
- 手動入力は `import_id = NULL` で自然に区別できる

### 支払い手段

**A. cards テーブルのまま**
- クレジットカード以外に拡張しにくい

**B. payment_methods テーブルに改名（採用）**
- クレカ・デビット・電子マネー・QR・現金を統一して管理
- ユーザーが自由に追加できる

---

## 決定事項

### 1. 原本と編集値を1テーブルに同居

```
transactions
  description      CSV生文字（不変）
  amount           CSV原本金額（不変）
  date             CSV原本日付（不変）

  merchant_name    編集可（自動生成 → ユーザー上書き可）
  category_id      編集可
  amount_override  金額訂正値（NULL なら原本を使用）
  date_override    日付訂正値（NULL なら原本を使用）
  effective_amount 集計用金額（generated: COALESCE(amount_override, amount)）
  effective_date   集計用日付（generated: COALESCE(date_override, date)）
  deleted_at       ソフトデリート
```

**理由**
- JOIN なしで原本と編集値が取得できる
- 個人利用レベルのデータ量でパフォーマンス問題なし

### 2. imports テーブルで取り込み履歴を管理

```
imports
  user_id
  payment_method_id
  filename
  file_hash         重複防止
  row_count
  imported_at
```

`transactions.import_id = NULL` が手動入力を表す。

**理由**
- CSV 由来の明細をまるごと取り消せる
- 手動入力と CSV 由来の区別が明確

### 3. cards → payment_methods に改名

**payment_type の値**
- `credit`：クレジットカード
- `debit`：デビットカード
- `e_money`：電子マネー（Suica など）
- `qr`：QR コード決済（PayPay・楽天Pay など）
- `cash`：現金

**理由**
- 現金・QR 決済など CSV 以外の手動入力に対応するため
- ユーザーが支払い手段を自由に追加できる設計

---

## 将来の拡張候補

- レシート画像・OCR による取り込み（`imports.source_type` で csv / image / manual を区別）
- 重複チェック: file_hash（完全一致）+ 日付範囲（同月データの存在確認）の2段階

---

## 結果

詳細なテーブル定義は [DATABASE_DESIGN.md](../DATABASE_DESIGN.md) を参照。
