# ADR-0037: S9 取り込み履歴一覧・詳細の実装計画

- 日付: 2026-08-18
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0036 取り込み取り消し](0036-s9-import-cancel-plan.md) / [ADR-0019 取り込み・支払方法設計](0019-import-and-payment-method-design.md)
- 対象 Issue: #47（取り込み履歴一覧・詳細）

---

## コンテキスト

取り込み履歴（`/imports`）を最小のリスト表示から一覧＋詳細画面にする。#46 の取り消しを実装済みなので、**取消済みかどうか**を一覧・詳細で分かるようにし、詳細では**その取り込みに含まれる明細一覧**を見せる。取り込みのライフサイクル（取込→履歴確認→取消）の可視化を完成させる。

---

## 論点と決定

- **取消済み表示は集約クエリで N+1 回避**: 一覧の「取込済/一部取消/取消済」は Import ごとに count を発行せず、`Current.user.transactions.not_deleted.where(import_id: 表示中id).group(:import_id).count` を1本引いて各行へ配る。判定は `active_count`（未削除件数）と `row_count`（原本件数）の比較: `0 && >0`→取消済、`0 < active < row_count`→一部取消、その他→取込済。
- **詳細の明細一覧は取消済みも含めて表示**（取消後も「何を取り込んだか」を確認できる）。取消済み行はバッジ/淡色で区別。並びは既存の明細一覧と揃え `effective_date` 降順。
- **取り消し導線**は `active_count.positive?` の Import にのみ表示（一覧・詳細）。
- **所有権**: `set_import`＝`Current.user.imports.find`（他ユーザー・存在しないは 404）を `show` にも適用。

---

## 実装

- **routes**: `resources :imports` に `show` 追加。
- **ImportsController**: `index` に `@active_counts`（集約クエリ）、`show`（`@transactions` = 明細一覧、`@active_count`）。
- **views**: `imports/index`（Tailwind テーブル・状態・詳細/取消導線）、`imports/show`（メタ情報＋明細一覧・取消済バッジ）。source_type は view で日本語表示（csv→CSV取り込み / manual_bulk→手動まとめ入力）。

---

## スコープ外（後続）

- 再取り込み・undo・ページネーション・CSV 再ダウンロード。#52 FE 横断・#53 共通横断。
