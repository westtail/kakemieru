# ADR-0036: S9 取り込み取り消しの実装計画

- 日付: 2026-08-18
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0033 明細の Turbo Stream/ソフト削除](0033-s8-transactions-turbo-stream-plan.md) / [ADR-0019 取り込み・支払方法設計](0019-import-and-payment-method-design.md) / [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md)
- 対象 Issue: #46（取り込み取り消し）

---

## コンテキスト

取り込んだ明細を取り込み単位でまとめて取り消す（ソフト削除）。確認画面を挟み、[実行]で紐づく `transactions` 全件の `deleted_at` をセットする。既存の soft delete（#44・`not_deleted` スコープ）を活用する。

---

## 論点と決定

- **Import レコードは残す**（destroy しない）。`has_many :transactions, dependent: :restrict_with_exception` のため、明細を持つ Import の destroy は例外になる。取り消し＝明細のソフト削除であり、Import 行は履歴として温存する。
- **file_hash を温存**（＝取り消し後も同ファイル再取り込みはエラー）。取り消しは「明細を消す」であって「取り込み自体を無かったことにする」ではない。重複取り込み防止（file_hash UNIQUE）はそのまま維持する。Issue #46 の spec もこの挙動を要求。
- **一括ソフト削除は `update_all(deleted_at: Time.current)`**（1クエリ）。`deleted_at` は `attr_readonly` 対象外で安全。所有権は `Current.user.imports.find`（他ユーザーは 404）＋ `@import.transactions`（Import 経由でテナント内に閉じる）で担保。
- **確認フロー**: `GET /imports/:id/cancel_confirm`（件数と警告を表示）→ `DELETE /imports/:id/cancel`（実行）。確認画面自体が確認手段のため turbo_confirm ダイアログは付けない。

---

## 実装

- **routes**: `resources :imports` の member に `get :cancel_confirm` / `delete :cancel`。
- **ImportsController**: `set_import`（所有権スコープ・404）、`cancel_confirm`（`@active_count`）、`cancel`（`transactions.not_deleted.update_all(deleted_at:)` → `/imports` へ「N件…取り消しました」）。
- **views**: `imports/cancel_confirm`（警告＋件数＋実行/戻る）、`imports/index` に「取り消し」導線を追加（履歴の本格整形は #47）。

---

## スコープ外（後続）

- 取り込み履歴の本格一覧・詳細（#47）。取り消しの undo・個別明細の物理削除。
