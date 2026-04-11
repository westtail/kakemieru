# ADR-0019: Import テーブルの定義と PaymentMethod 初期生成

- 日付: 2026-04-11
- ステータス: 決定済み

---

## コンテキスト

以下の2点について設計方針を決定する必要があった。

1. `imports` テーブルの役割定義と将来の入力経路への対応方針
2. 現金など CSV なしの支払手段をどう扱うか（`payment_method_id` の nullable 可否）

---

## 議論した選択肢

### Import テーブルの定義

**案A: 「データの取り込み操作の記録」として広く定義（採用）**
- `source_type` で csv / ocr / api / manual_bulk を区別
- 1テーブルで全入力経路を管理・シンプル

**案B: Import = CSV 取り込みに限定**
- 他の入力方法は別テーブル（api_imports / receipt_imports など）
- 明確だが将来テーブルが増える

**案C: Import をなくして PaymentMethod 側に取り込み設定を持たせる**
- 1回の取り込みで生まれる Transaction 全件に同じファイル情報が重複する問題が発生
- 「1回の取り込み操作」という単位を表す器がなくなるため不採用

### 現金・手動入力の扱い

**案X: `payment_method_id = NULL` を許容（手動入力 = 支払方法未指定）**
- 現金を事前登録しなくても手動入力できる
- 支払方法別集計で NULL が混じり複雑になる
- `payment_method_id` が nullable になり整合性チェックの経路が1本減る

**案Y: ユーザー登録時に「現金」PaymentMethod を自動生成（採用）**
- `category_templates → categories` のコピー方式と同じ発想
- `payment_method_id` を NOT NULL のまま維持できる
- 支払方法別集計が崩れない

---

## 決定事項

### 1. Import テーブルの定義

**Import = 「1回の取り込み操作をまとめる単位」**

CSV・OCR・API連携など入力経路に関わらず、複数の Transaction を1つの操作としてまとめる器。

```
imports
  id
  user_id
  payment_method_id
  source_type        # csv / ocr / api / manual_bulk（フェーズ1は csv 固定）
  source_ref         # 取り込み元の参照情報（csv: ファイル名、ocr: 画像ファイル名、api: エンドポイント識別子、manual_bulk: NULL）
  file_hash          # 重複取り込み防止
  row_count          # 取り込み件数
  imported_at
```

**理由**
- 1回の取り込みで生まれる Transaction 全件に同じ情報を持たせると冗長になる
- `import_id` で「この取り込みをまるごとやり直す」操作が自然に書ける
- `source_type` を今から持つことで将来の拡張時にスキーマ変更が不要

### 2. `import_id = NULL` の意味を明文化

```
import_id あり → 何らかの取り込み操作由来（CSV・OCR・API など）
import_id なし → ユーザーによる手動1件入力
```

フェーズ1では `source_type = csv` のみ使用。他の値は将来の拡張時に追加する（YAGNI）。

### 3. 「現金」PaymentMethod の自動生成

ユーザー登録時に `payment_type: cash` の PaymentMethod を1件自動生成する。

```ruby
# ユーザー登録時
user.payment_methods.create!(
  name: "現金",
  payment_type: "cash"
)
```

**理由**
- 手動入力のたびに「現金という支払方法を先に作ってください」はUXが悪い
- `payment_method_id` を NOT NULL のまま維持できる（マルチテナント分離の経路を保つ）
- 支払方法別集計に NULL が混入しない

### 4. `payment_method_id` は NOT NULL を維持

`payment_method_id = NULL`（支払方法未設定）は許容しない。手動入力時は必ず「現金」など何らかの PaymentMethod を選択する。

---

## 各テーブルの役割定義（まとめ）

| テーブル | 役割 |
|---|---|
| `payment_methods` | 「何で払ったか」の管理。クレカ・現金・QRなど支払手段の種別 |
| `imports` | 「どう取り込んだか」の管理。1回の取り込み操作の記録・単位 |
| `transactions` | 明細1件。`payment_method_id`（支払手段）と `import_id`（取り込み操作）の両方を持つ |

**payment_methods と imports は独立した関心事**

- `payment_methods` は支払手段の「種別・設定」
- `imports` は取り込みの「操作・履歴」
- 1つの PaymentMethod に対して複数の Import が紐づく（毎月のCSV取り込みなど）

---

## 保留事項

- `source_type` の値の追加は実装時に決定（OCR・API連携のフェーズで）
- `filename` カラムは `source_ref` に改名済み（DB-H3 対応）。source_type に応じた参照情報を格納する

---

## 結果

詳細なテーブル定義は [DATABASE_DESIGN.md](../DATABASE_DESIGN.md) を参照。
