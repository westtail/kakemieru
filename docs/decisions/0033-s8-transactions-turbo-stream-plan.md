# ADR-0033: S8 明細のカテゴリ即時変更・削除（Turbo Stream）

- 日付: 2026-08-16
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0031 一覧・絞り込み](0031-s8-transactions-filter-plan.md) / [ADR-0032 明細編集](0032-s8-transaction-edit-plan.md) / [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md)
- 対象 Issue: #44（カテゴリ即時変更・削除 Turbo Stream）

---

## コンテキスト

明細一覧（#43）の各行で、カテゴリをその場で変更でき、行を削除（ソフトデリート）できるようにする。ページ遷移なしの部分更新を **Turbo Stream** で実現する（アプリ初の Turbo Stream。turbo-rails は導入済み・使用箇所ゼロ）。削除は確認バナー（「削除しますか？ [確定][キャンセル]」）を挟む。

---

## 論点と決定

- **確認バナーの表示/取消は Stimulus（クライアント）**、実際の変更（カテゴリ更新・行削除）は **Turbo Stream**。バナーの開閉に往復を挟まず round-trip を最小化する。
- **インラインのカテゴリ変更は専用の member アクション `categorize`（Turbo Stream 専用）に分離**する。理由: #41 の全画面編集 `update` は HTML リダイレクトで、Turbo はフォーム送信時に turbo-stream を要求するため、`update` に turbo_stream を混ぜると全画面編集が壊れる。責務を分けることで両立させる。
- 行を partial 化し `<tr id="<%= dom_id(transaction) %>">` を付与 → `turbo_stream.replace/remove` の対象にする。
- 削除は物理削除せず `deleted_at`（既存のソフトデリート方針・`not_deleted` スコープ）。`Transaction#soft_delete!` を追加。`deleted_at` はサーバー側のみで設定（permit しない）。
- 所有権: `set_transaction` は `Current.user.transactions.not_deleted.find`。他ユーザー・削除済みは 404。他ユーザーの `category_id` はモデルのテナント整合で拒否し、`reload` で元表示に戻す。

---

## 実装

- **routes**: `resources :transactions` に `destroy` と member `patch :categorize` を追加。
- **TransactionsController**: `categorize`（category_id のみ permit → 更新 → reload → `turbo_stream.replace` で行を差し替え）、`destroy`（`soft_delete!` → `turbo_stream.remove`）。`update`（#41）は現状維持。
- **Transaction#soft_delete!**。
- **views**: 行 partial `transactions/_transaction`（カテゴリ=インライン select フォーム、操作=編集＋削除確認バナー）。`index` は collection レンダリングへ。
- **Stimulus**: `auto-submit`（select 変更でフォーム送信）、`confirm-delete`（バナー開閉）。

---

## スコープ外・既知の制限

- 絞り込み中にカテゴリを変えると、その行はフィルタ条件から外れても再読込までは残る（行を replace するだけのため）。リロードで整合。
- 削除の取り消し（undo）・一括削除・payment_method のインライン変更は範囲外。取り込み単位の取り消しは #46。
