# ADR-0044: 明細一覧の列ソート

- 日付: 2026-08-26
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0031 明細フィルタ](0031-s8-transactions-filter-plan.md)
- 対象 Issue: #147

---

## コンテキスト

明細登録後にカテゴリをまとめて付ける際、同じ店舗を隣接させたい（店舗名ソートが直近の用途）。将来的に各列でソートしたい要望のため、汎用のソート機構を入れる。現状は `order(effective_date: :desc, id: :desc)` の固定順。

## 決定

- 一覧ヘッダーのクリックでソート。対象は **5列**: 日付(effective_date) / 店舗名(merchant_name) / 金額(effective_amount) / カテゴリ(name) / 支払方法(name)。
- **ソート列・方向はホワイトリストで検証**（`SORTABLE = %w[date merchant amount category payment_method]`、`direction` は `asc` 以外を `desc` に倒す）。ユーザー入力を SQL に補間しない。
- 並び順は **Arel ノード**で構築（`arel_table[:col].asc/desc`）。生 SQL 文字列補間を避け、SQLi/brakeman を安全側に。安定タイブレークに `id: :desc` を付ける。
- カテゴリ/支払方法は**名前順**。`includes(:category, :payment_method)` に `references` を併用して LEFT OUTER JOIN で並べる（該当ソート時のみ）。
- **未分類（category NULL）は昇順・降順とも末尾に固定**（Arel の `.nulls_last`。生 SQL は使わない）。方向で位置が変わらず一貫。
- ヘッダーのソートリンクは**既知の絞り込みパラメータ（month/category/q）だけ**を引き継ぐ（想定外パラメータや sort キー重複を持ち回らない）。
- **既定は日付降順**（現状の挙動を維持）。絞り込み（月/カテゴリ/キーワード）はソートと併用しても維持する。
- ヘッダーは現在のソート列に矢印（`▲`/`▼`）、非アクティブ列は薄い `↕` でソート可能を示唆。

## スコープ外

- 複数列の複合ソート、ソート状態の永続化（URL パラメータのみ）、手動一括入力テーブルのソート。
