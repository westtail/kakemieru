# ADR-0028: S6（前半）CSV取り込み保存・自動分類の実装計画

- 日付: 2026-08-15
- ステータス: 承認（スコープA・論点確定）
- 関連: [ADR-0012 CSV取り込み戦略](0012-csv-import-strategy.md) / [ADR-0015 カテゴリ分類方針](0015-category-classification-strategy.md) / [ADR-0026 S5取り込み](0026-s5-csv-import-plan.md) / [ADR-0027 S7明細](0027-s7-transactions-plan.md)
- 対象 Issue: #36（アップロード・保存）/ #35（カテゴリ自動割り当て）

---

## コンテキスト

S5（パーサー）と S7（transactions）が揃い、「**CSV アップロード → Import + 明細を一括保存**」というアプリの核心を実装する。スコープは **A（CSV取り込みを先に）**: #36 + #35 + 最小の `/imports` 一覧。**#34 手動まとめ入力（Stimulus 動的行 + アプリ初の Turbo Stream）は別スライスに後回し**。エラーは通常の再レンダリングで表示し、本スライスでは Turbo Stream を導入しない。

---

## 論点と決定

1. **成功時リダイレクト**: 取り込んだ明細の**最新月**の `/transactions?month=YYYY-MM` へ（SCREEN_DESIGN 準拠・結果が見える）。flash「◯件を取り込みました」。（Issue 本文の `/imports` と食い違うが、結果確認できる SCREEN_DESIGN を採用。）
2. **ファイルサイズ上限 5 MB**（DoS 対策・カード明細には十分）。超過は保存せずエラー。
3. **パーサー行数上限**（S5 繰り延べ）: `CsvParser::RakutenCard` に `MAX_ROWS = 10_000` を追加、超過はエラー収集して打ち切り。
4. **source_ref サニタイズ**（S5 繰り延べ）: `File.basename(original_filename)` + 制御文字除去 + 長さ制限。パス結合に使わない（表示・保存のみ）。
5. **ファイル受け取り**: ActiveStorage は使わず `params` の UploadedFile を `.read`。CSV 本体は保存せず `file_hash = Digest::SHA256.hexdigest(content)` のみ保持。
6. **重複チェック**: `user.imports.find_by(file_hash:)` があれば「取り込み日 に取り込み済み」+ /imports リンク。競合対策に `RecordNotUnique` も rescue。
7. **原子性**: Import 1件 + Transaction N件を1トランザクション。1行でも失敗すれば全ロールバックし、パースエラー + 行エラーをまとめて再表示。
8. **#35 フェーズ1**: `merchant_classifications` は空なので実質全件未分類（category_id=NULL）。将来テーブルが埋まれば自動で効く仕組みだけ用意する。実装は **category_key ベース**（旧 CATEGORY_CLASSIFICATION.md の category_id/user_id/confidence は無視。DATABASE_DESIGN/ADR-0015 が正）。
9. **manual_bulk の file_hash** 問題は本スライス範囲外（#34 後回し）。

---

## 実装

- **`Imports::CsvImporter`**（`app/services/imports/csv_importer.rb`）: サイズ確認 → read → file_hash → 重複確認 → `CsvParser::RakutenCard.parse` → トランザクション内で Import + `import.transactions.build(...).save` ループ（バリデーションを効かせるため insert_all は使わない）→ 失敗行/パースエラーを収集し errors があれば Rollback。`Result(import:, errors:)` を返す。
- **`MerchantClassification`** モデル（テーブル既存）+ **`CategoryClassifier.category_id_for(user, merchant_name)`**（merchant_name→category_key→user の category_id、無ければ nil）。
- **`ImportsController`**（new/create/index）: `Current.user.payment_methods.find` で所有権スコープ、生 params を Import に渡さない。errors なしで `/transactions?month=` へ、ありで `render :new, 422`。index は最小一覧。
- **routes**: `resources :imports, only: %i[index new create]`。ビュー・ダッシュボード導線。
- **パーサー**: `MAX_ROWS` 追加。

---

## テスト
- `Imports::CsvImporter` spec（正常・重複・パースエラー・サイズ超過・不正行ロールバック）
- `CategoryClassifier` spec（空→nil・一致→id・正規化）/ `MerchantClassification` spec
- `imports` request spec（未ログイン・new・create正常/重複/不正/他ユーザー支払方法拒否）
- parser MAX_ROWS spec

## スコープ外
- #34 手動まとめ入力・Turbo Stream・取り込み履歴詳細/取り消し（S9 #47/#46）・#37 デプロイ・複合FK(#113)
