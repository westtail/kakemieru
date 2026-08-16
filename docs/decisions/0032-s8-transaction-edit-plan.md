# ADR-0032: S8 明細編集の実装計画

- 日付: 2026-08-16
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0031 明細一覧・絞り込み](0031-s8-transactions-filter-plan.md) / [ADR-0027 S7明細](0027-s7-transactions-plan.md) / [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md)
- 対象 Issue: #41（明細編集）

---

## コンテキスト

#43 で一覧・絞り込みができるようになった明細を、1件ずつ編集できるようにする。CSV 原本（date/amount/description）は不変・表示のみで、訂正は override 列に入れる、というモデル方針（`app/models/transaction.rb`）に沿う。一覧→編集の導線を通す。

---

## スコープ（Issue #41 準拠）

- **編集可能**: `merchant_name` / `category_id` / `amount_override` / `date_override`。
- **表示のみ（原本）**: `date` / `amount` / `description`。
- **対象外**: payment_method の変更、削除。SCREEN_DESIGN では編集画面に削除も並ぶが、#41 は編集のみとし、削除は別スライスに送る。

---

## 論点と決定

- **原本の不変性**: `date`/`amount` は `attr_readonly`。update では permit せず、訂正は `amount_override`（整数・int4・nil可）/`date_override`（日付・nil可）に入れる。`effective_amount`/`effective_date` は STORED 生成カラム（`COALESCE(override, 原本)`）で自動追従。
- **所有権/404**: `set_transaction` を `Current.user.transactions.not_deleted.find(params[:id])` にし、他ユーザー・削除済みは `RecordNotFound`＝404（`test.rb` は `show_exceptions = :rescuable` で request spec でも 404）。categories 編集の `set_category` と同型。
- **保存後遷移**: 更新後の `effective_date` の月の `/transactions?month=YYYY-MM` へ（作成時と揃える。訂正で月が変わる場合も移動先が正しい）。
- **訂正バッジ**: `Transaction#corrected?`（`amount_override` か `date_override` が present）で一覧行にバッジ表示。
- **空欄＝訂正なし**: override 欄を空にすると nil（訂正解除）。`date_override_is_valid_date` が不正日付を弾く。

---

## 実装

- **routes**: `resources :transactions` に `edit update` を追加。
- **TransactionsController**: `before_action :set_transaction`（edit/update）、`edit`、`update`、`transaction_update_params`（`merchant_name`/`category_id`/`amount_override`/`date_override` のみ permit）。編集フォーム用 `@categories`。
- **Transaction**: `corrected?` を追加。
- **views/transactions/edit**（新規）: 原本の読み取り表示＋ override 等の編集フォーム（categories の `_form`/`shared/error_messages` パターン踏襲）。
- **views/transactions/index**: 操作列（編集リンク）＋訂正バッジを配線（#43 で保留していた操作列）。

---

## スコープ外（後続）

- 明細の削除（ソフトデリート）、カテゴリ即時変更 Turbo Stream（#44）、payment_method の変更。
