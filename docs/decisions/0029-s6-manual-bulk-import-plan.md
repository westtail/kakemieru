# ADR-0029: S6（後半）手動まとめ入力の実装計画

- 日付: 2026-08-15
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0028 S6 CSV取り込み](0028-s6-csv-import-save-plan.md) / [ADR-0019 取り込み・支払方法設計](0019-import-and-payment-method-design.md) / [ADR-0027 S7明細](0027-s7-transactions-plan.md)
- 対象 Issue: #34（手動まとめ入力）

---

## コンテキスト

CSV が無い明細（現金など）を、テーブル形式で複数行まとめて入力し `Import(source_type: manual_bulk)` + `Transaction N件` を1トランザクションで保存する。これで S6 の入力2モード（CSV / 手動まとめ）が揃う。CsvImporter（#36）と同型のサービスで実装する。

**スコープ**: Turbo Stream は後回し（S8 #44）。エラーは通常の再レンダリング（送信行を保持）。Stimulus（行の追加/削除・デフォルト支払方法プリセット）をアプリ初の対話JSとして導入。

---

## 論点と決定

- **manual_bulk の file_hash**（S6 前半で繰り延べ）: `SecureRandom.hex(32)`。手動入力は重複判定しない（毎回一意）。Import の `file_hash` NOT NULL / UNIQUE を満たす。`source_ref` は NULL（`import.rb` が `manual_bulk?` で presence 免除済み）。
- **Import.payment_method（NOT NULL）**: フォームの「デフォルト支払方法」を使う。各明細行は行ごとの支払方法（未指定はデフォルト）。
- **50行上限**: サーバー側バリデーション。Stimulus は上限で「行を追加」ボタンを無効化。
- **空行スキップ**: 全項目空の行は除外。実入力0行ならエラー。
- **成功時リダイレクト**: 入力明細の最新月の `/transactions?month=YYYY-MM`（CSV と揃える）。
- **タブ**: `/imports/new` に「CSVから取り込む」「手動でまとめて入力」の2セクション併置（重装タブJSは入れない）。
- **テナント整合**: 他ユーザーの category/payment_method は Transaction のモデルバリデーションで拒否（複合FL不採用の代替・#113 は別途）。

---

## 実装

- **`Imports::ManualBulkImporter`**（`app/services/imports/manual_bulk_importer.rb`）: `Result(import:, errors:)`。空行除外・0行/50件超チェック → `Import(manual_bulk, file_hash: SecureRandom, payment_method: default)` + 各行 `import.transactions.build(...).save`（行ごと payment_method・未指定はデフォルト）→ 失敗収集し errors あれば Rollback。CsvImporter の原子性/エラーパターンを踏襲。
- **`ImportsController`**: `new` に `@categories`・`@manual_rows` を追加。`create_manual`（POST /imports/manual）で default を所有権スコープ find、rows を受け取りサービス呼び出し。成功で `/transactions?month=`、失敗で 422 再描画（送信行保持）。
- **ビュー**: `imports/new` に手動セクション、`imports/_manual_row`（`manual[transactions][][field]` 配列）。
- **Stimulus** `bulk_entry_controller`: 行追加（template 複製 + デフォルト支払方法プリセット）・削除・50行で無効化。
- **routes**: `post "imports/manual", to: "imports#create_manual", as: :manual_import`。

---

## テスト
- `manual_bulk_importer_spec`: 複数行生成 / 空行スキップ / 0行・50件超エラー / 不正行ロールバック / 行ごと支払方法・未指定デフォルト / 他ユーザー資源拒否 / file_hash 毎回一意。
- `imports_spec`（追記）: 手動セクション表示 / POST 正常 / エラー時 422+入力保持 / デフォルト未選択で案内。

## スコープ外
- Turbo Stream（行単位差し替え）→ S8 #44。デフォルト変更時の既存行 retro 更新 → 新規行プリセットのみ。#37 デプロイ・S8 は後続。
