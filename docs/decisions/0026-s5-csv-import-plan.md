# ADR-0026: S5 CSV取り込み土台の実装計画

- 日付: 2026-08-11
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0012 CSV取り込み戦略](0012-csv-import-strategy.md) / [ADR-0015 カテゴリ分類方針](0015-category-classification-strategy.md) / [ADR-0019 取り込み・支払方法設計](0019-import-and-payment-method-design.md) / [ADR-0025 S4 支払方法](0025-s4-payment-methods-plan.md)
- 対象 Issue: #33（migration）/ #31（Import モデル）/ #32（楽天CSVパーサー）

---

## コンテキスト

フェーズ1 実装単位 S5「CSV取り込みの土台」。**テーブル + モデル + パーサーのみ**を作る。アップロード画面（S6）・transactions レコード生成（S7）は範囲外。パーサーは「Transaction 属性のハッシュ配列を返すだけ」でレコードは作らない。

| Issue | 内容 |
|---|---|
| #33 | [migration] imports / merchant_classifications テーブル |
| #31 | Import モデル + spec |
| #32 | CsvParser::RakutenCard（楽天カードCSVパーサー）+ spec |

---

## 前提・既知の落とし穴（決定）

- **Ruby 3.4 で `csv` は bundled gem に降格**。`require "csv"` を使うため **Gemfile に `gem "csv"` を追加**する（未追加だと非推奨警告→将来エラー）。
- **ドキュメント不整合**: `CATEGORY_CLASSIFICATION.md` の merchant_classifications 定義（`category_id` / `user_id NOT NULL` / `confidence`）は**旧版**。DATABASE_DESIGN・ADR-0015・Issue #33 の定義（`category_key` / user_id なし / 全ユーザー共通）を**正**とする。旧ドキュメントの修正は本スライス範囲外（別途）。

---

## テーブル設計（#33・決定）

### imports

| カラム | 型 | 制約 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | NOT NULL / FK → users |
| payment_method_id | bigint | NOT NULL / FK → payment_methods |
| source_type | string | NOT NULL / CHECK(csv,ocr,api,manual_bulk) |
| source_ref | string | nullable（manual_bulk 以外は必須＝アプリ層で検証） |
| file_hash | string | NOT NULL |
| row_count | integer | NOT NULL / default 0 |
| imported_at | datetime | nullable（取り込み時刻・S6 で設定） |
| timestamps | | |

- **インデックス**: `UNIQUE(user_id, file_hash)`（重複取り込み防止）+ payment_method_id 索引（FK 用）。user_id は複合の先頭でカバーされるため単独索引なし。
- 複合FK `(user_id, id)` は**不要**（transactions の複合FKは category のみ・DATABASE_DESIGN L317）。

### merchant_classifications（全ユーザー共通・フェーズ1は空）

| カラム | 型 | 制約 |
|---|---|---|
| id | bigint | PK |
| merchant_name | string | NOT NULL / UNIQUE |
| category_key | string | NOT NULL / index |
| source | string | NOT NULL / CHECK(ai,user_manual) |
| classified_at | datetime | nullable |
| timestamps | | |

- **user_id を持たない**（category_key で全ユーザー共通のマッピング）。S5 ではテーブルのみ・モデルは作らない（使うのは S6）。

CHECK 制約の値はマイグレーションにインライン（履歴を不変に）。

---

## モデル設計（#31・決定）— `app/models/import.rb`

- `belongs_to :user` / `belongs_to :payment_method`
- `enum :source_type, ImportCatalog::SOURCE_TYPES.index_with(&:itself), validate: true`（S4 の enum パターン踏襲。定数は `config/constants/imports.rb`）
- `validates :source_type, presence: true`
- `validates :file_hash, presence: true, uniqueness: { scope: :user_id }`（DB UNIQUE と二重。scoped_to は FK のため spec は明示テスト）
- `validates :source_ref, presence: true, unless: -> { manual_bulk? }`
- **`has_many :transactions` は S7 へ繰り延べ**（transactions テーブル未作成。ADR-0022/0025 の方針）
- 関連の dependent（DATABASE_DESIGN の ON DELETE ポリシーに整合させる）:
  - `User` → `has_many :imports, dependent: :destroy`。**users 削除は CASCADE**（退会時に全データ削除）なので、imports もユーザーと一緒に消す。`payment_methods` より先に宣言し、退会カスケードで payment_methods の restrict にかからないようにする。
  - `PaymentMethod` → `has_many :imports, dependent: :restrict_with_exception`。取り込み履歴を持つ支払方法の物理削除を防ぐ。
  - 「imports 削除 → RESTRICT」（DATABASE_DESIGN）は transactions→imports の関係（直接の物理削除禁止）であり、S7 で `Import has_many :transactions, dependent: :restrict_with_exception` として実装する。退会の CASCADE とは別レイヤ。

---

## パーサー設計（#32・決定）— `app/services/csv_parser/rakuten_card.rb`

`CsvParser::RakutenCard`。Shift-JIS の楽天カードCSVを受け取り、Transaction 属性ハッシュ配列と不正行エラーを返す（レコードは作らない）。

- 入力: CSV の生バイト列（文字列）。内部で `force_encoding("Shift_JIS").encode("UTF-8", invalid: :replace, undef: :replace)` に変換。
- **ヘッダー検出**: 「利用日」を含む行までスキップ（先頭の口座サマリー行を飛ばす）。
- 使う列: `利用日`→date（`Date.parse`）/ `利用店名・商品名`→description / `利用金額`→amount（カンマ除去して整数）。利用者・支払方法・手数料・総額は無視。
- `merchant_name` = description を正規化（`unicode_normalize(:nfkc)` で全角→半角 + strip、255 文字まで）。
- 戻り値: `Result(rows:, errors:)`。日付・金額が不正な行はスキップして errors に収集。
- `require "csv"` を明示。

### spec（`spec/services/csv_parser/rakuten_card_spec.rb`）
Shift-JIS 文字列をテスト内で `"...".encode("Shift_JIS")` で生成。検証: 正常パース / カンマ除去 / 日付変換 / 先頭サマリー行スキップ（ヘッダー自動検出）/ 不正日付行のスキップとエラー収集 / merchant_name 正規化。

---

## 実装順序（TDD）

```text
1. ADR + ブランチ + Gemfile に gem "csv" 追加・bundle
2. config/constants/imports.rb + application.rb require
3. #33 migration ×2（imports / merchant_classifications）→ 可逆性・schema 確認
4. #31 Import spec(RED) → Import モデル + User/PaymentMethod has_many :imports(GREEN)
5. #32 パーサー spec(RED) → CsvParser::RakutenCard(GREEN)
6. 全スイート + rubocop + brakeman → ruby/security レビュー → 分割コミット → PR
```

## 検証
- rspec 全緑 / rubocop / brakeman / migration rollback STEP=2・redo
- 手動: `CsvParser::RakutenCard.parse(sjis_csv)` が rows を返す（console）

## スコープ外
- アップロード画面 `/imports/new`・file_hash 計算・重複エラー表示 → **S6**
- transactions 生成・`Import has_many :transactions` → **S7**
- merchant_classifications の中身投入・分類ロジック → S6 以降（フェーズ1は空）

### S6 の受入基準に必ず引き継ぐこと（S5 レビュー指摘の繰り延べ分）
本スライスには CSV を受け取る入口が無いため以下は S6 で対応する。Issue 化して取りこぼさないこと。
- **ファイルサイズ / 行数の上限**（DoS 対策）。パーサーにも防御的な行数上限を検討。
- **`source_ref`（ファイル名）のサニタイズ**: 表示・保存のみに使い、パス結合に使わない。`File.basename` 化・`../`/制御文字除去。
- **コントローラの current_user スコープ**: `current_user.payment_methods.find(...)` / `current_user.imports.build(...)` を徹底し、`payment_method_id` を生 params から Import に渡さない（Import のテナント整合バリデーションは多層防御として実装済み）。
- 将来 CSV エクスポート機能を作る場合の **CSV インジェクション**対策（先頭 `= + - @` のエスケープ）。
