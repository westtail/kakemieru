# ADR-0034: S9 サマリー API の実装計画

- 日付: 2026-08-17
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0031 一覧・絞り込み](0031-s8-transactions-filter-plan.md) / [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md) / [SUMMARY_API.md](../design/SUMMARY_API.md)
- 対象 Issue: #45（サマリー API）、#14（SUMMARY_API の GET 専用・CSRF ポリシー明文化）

---

## コンテキスト

ダッシュボード（#48・Chart.js）が消費する月次集計 JSON を返す `GET /transactions/summary` を実装する。集計は `effective_amount`/`effective_date`（DB 生成カラム）＋ `not_deleted` スコープで行い、カテゴリ別に降順で返す。#14 が求める GET 専用制約・CSRF ポリシーの明文化も本 PR で対応する（`docs/design/SUMMARY_API.md`）。

---

## 論点と決定

- **`total` は `effective_amount` の符号付き合計**（返金明細のマイナスも反映した純額）。カテゴリ別 amount も符号付き。
- **CSRF 隔離（#14）**: `protect_from_forgery with: :null_session` はコントローラ全体の CSRF 戦略を変える。書き込みを持つ `TransactionsController` に付けると将来の書き込みアクションの CSRF 防御が失われるため、**読み取り専用の専用コントローラ `Transactions::SummariesController`** に隔離する。書き込み系は既定の `:exception` 戦略を維持。
- **未認証は 401**（HTML のようにリダイレクトしない）: `require_authentication`（`app/controllers/concerns/authentication.rb`）を `allow_unauthenticated_access` で外し、`resume_session` が偽なら `head :unauthorized`。`resume_session` は有効セッションで `Current.session` をセットするため、認証時は `Current.user` が使える。
- **不正 `month` は 422**: `Date.strptime(value, "%Y-%m")`。文字列以外・空・パース不能は 422。

---

## 実装

- **routes**: `resources :transactions` の collection に `get :summary, to: "transactions/summaries#show"`。
- **`Transactions::SummariesController#show`**: month をパース（不正→422）、`Transactions::MonthlySummary` を呼び JSON を返す。`allow_unauthenticated_access` + `require_json_session`（401）+ `protect_from_forgery with: :null_session`。
- **`Transactions::MonthlySummary`**（`app/services/transactions/monthly_summary.rb`）: `not_deleted.in_month` を `group(:category_id).sum(:effective_amount)` で集計 → `{ month, total, categories:[{id,name,amount}] }`（amount 降順・未分類は `id:null/name:"未分類"`）。

---

## スコープ外（後続）

- ダッシュボード UI・Chart.js（#48）、収入/支出の内訳区分・予算比較。
- 取り込み取り消し（#46）・履歴詳細（#47）。
