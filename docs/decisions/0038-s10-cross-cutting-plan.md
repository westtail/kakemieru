# ADR-0038: S10 共通横断（エラーページ・ヘルスチェック・CSRF/認証/N+1 確認）

- 日付: 2026-08-19
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0034 サマリー API](0034-s9-summary-api-plan.md) / [ADR-0022 認証基盤](0022-s1-auth-foundation-plan.md)
- 対象 Issue: #53（共通横断）

---

## コンテキスト

本番稼働中アプリの品質仕上げとして、アプリ全体の横断項目をまとめて対応する。主眼は**ブランド化した動的エラーページ**（現状は Rails 既定の静的 `public/*.html`）。あわせて `/health` を足し、CSRF・認証適用・N+1 の状態を確認・明文化する。

---

## 論点と決定

- **エラーページは動的・ブランド化**: `config.exceptions_app = routes` にし、`/404`・`/422`・`/500` を `ErrorsController` にルーティングして `app/views/errors/*.html.erb` を表示する。**DB/セッションに依存しない専用の `layout "error"`** を使う（アプリのレイアウトはヘッダーで `authenticated?`→DB を触るため、エラー時の二次障害を避けて使わない）。**静的 `public/{404,422,500}.html` は削除**する（動的ルートを shadow するため）。描画自体が失敗した場合の最終フォールバックは Rails の FAILSAFE（プレーンテキスト）で、無限ループしない。`public/400.html`・`406-unsupported-browser.html` は据え置き。
- **ErrorsController は認証不要**（`allow_unauthenticated_access`）: エラーページで /sign_in にリダイレクトさせない。
- **`/health` は Rails のヘルスチェックを再利用**（`get "health" => "rails/health#show"`）。`/up`（Fly 用）は維持。
- **N+1 は手動監査＋明文化**（bullet gem は導入しない）。

---

## 確認結果（既に満たしている項目）

- **CSRF**: 既定 `:exception`（`ApplicationController < ActionController::Base`）。サマリー API のみ `Transactions::SummariesController` で `protect_from_forgery with: :null_session` に隔離（#45/#14）。書き込み系は通常保護。
- **認証適用**: `Authentication` concern が `before_action :require_authentication` を全体適用。除外（`allow_unauthenticated_access`）は sessions / registrations / passwords / transactions/summaries の4つのみ。
- **N+1 監査**: 一覧・集約系はすべて対応済み。
  - `TransactionsController#index`: `includes(:category, :payment_method)`。
  - `ImportsController#index`: `includes(:payment_method)` ＋ 未削除件数は `group(:import_id).count` の集約1本。
  - `ImportsController#show`: `includes(:category)`。
  - ダッシュボード: サマリー API（`MonthlySummary`）が `group(:category_id)` 集約2本。

---

## 実装

- `config/application.rb`: `config.exceptions_app = routes`。
- `config/routes.rb`: `/health` と `/404`・`/422`・`/500` を追加。
- `app/controllers/errors_controller.rb`（新規）: `allow_unauthenticated_access`、各 status でエラービュー描画。
- `app/views/errors/{404,422,500}.html.erb`（新規）: 見出し＋説明＋トップへ戻る。Tailwind。

---

## スコープ外

- bullet 常時導入・自動 N+1 検出、400/406 のカスタム、#52 FE 横断。
