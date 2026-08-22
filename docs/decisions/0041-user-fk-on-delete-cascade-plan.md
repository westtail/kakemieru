# ADR-0041: user 外部キーに DB レベルの ON DELETE CASCADE を張る

- 日付: 2026-08-22
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0013 DBモデル設計](0013-database-model-design.md) / [ADR-0017 DB設計クリティカル修正](0017-db-design-critical-fixes.md)
- 対象 Issue: #110

---

## コンテキスト

DATABASE_DESIGN は「users 削除 → CASCADE（退会時に全データ削除）」を規定するが、実際の外部キーは `on_delete` 指定を持たず、退会カスケードは Rails の `dependent: :destroy`（アプリ層）だけで担保していた。ActiveRecord を経由しない削除（生 SQL の `DELETE FROM users`・`delete_all` 等）では DB 制約に阻まれ、設計意図と乖離する。

PR #109（S5）のレビューで CodeRabbit が imports について指摘したが、imports だけ DB カスケードを足すと他テーブルと不整合になるため、本 ADR で横断対応する。

---

## 決定

users を直接参照する**全外部キー**に `on_delete: :cascade` を張るマイグレーションを1本追加する。対象は次の5テーブル:

- `categories → users`
- `imports → users`
- `payment_methods → users`
- `sessions → users`
- `transactions → users`

Issue の明示リストは4つ（categories / payment_methods / sessions / imports）だが、`transactions → users` も user 外部キーであり「全 user 外部キー」の趣旨に含まれる。また transactions を除外すると生 SQL の `DELETE FROM users` が transactions の FK で失敗するため、横断の一貫性としても transactions を含める。

`transactions → categories`（`on_delete: :nullify`）や `imports/transactions → payment_methods` など **user 以外**の FK は本 ADR の対象外（挙動を変えない）。子同士は user 削除時にいずれも user 経由で CASCADE 削除されるため、相互参照 FK に阻まれない。

`dependent: :destroy`（アプリ層）は退会時のコールバック・監査のため**併存**させる（DB カスケードと二重で守る）。

---

## 実装

- `db/migrate/*_add_on_delete_cascade_to_user_foreign_keys.rb`: 各 FK を `remove_foreign_key` → `add_foreign_key ..., on_delete: :cascade` で張り直す。`down` で無指定へ戻す。
- **単一 DDL トランザクション（Rails 既定）で実行**する。remove → add を原子的に行うことで、他セッションからは旧 FK か新 FK のどちらかしか見えず、「FK が一瞬消える隙間」が生じない（その隙間での `DELETE FROM users` による子行の孤児化を防ぐ）。対象テーブルは小規模のため検証スキャンのロックも短時間で許容範囲。将来テーブルが肥大化してロックが問題になる場合は、一時名の cascade FK を先に足して検証後に旧 FK を落とすオンライン方式に切り替える（`disable_ddl_transaction!` + NOT VALID だけでは上記の孤児化ウィンドウが残るため単純採用しない）。
- 検証: `spec/models/user_spec.rb` に、`delete_all`（コールバック非経由）で全子レコードが消え FK 違反にならないことのテストを追加。

## スコープ外

- user 以外の外部キーの削除挙動変更。
- 退会フロー（`AccountsController#destroy`）自体の変更（アプリ層カスケードは維持）。
