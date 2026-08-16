# ADR-0030: Tailwind CSS の導入

- 日付: 2026-08-16
- ステータス: 承認（スコープ確定）
- 関連: [PROJECT_ABOUT.md](../PROJECT_ABOUT.md)（技術スタックに Tailwind CSS 記載） / [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md)（CSS フレームワークは Tailwind） / [ADR-0005 CI/CD](0005-cicd-pipeline.md)
- 対象 Issue: #119（Tailwind CSS 導入）

---

## コンテキスト

設計ドキュメントは当初から CSS フレームワークに Tailwind CSS を前提としている（`PROJECT_ABOUT.md` / `SCREEN_DESIGN.md`）が、正式な意思決定記録も導入もないまま進み、現状の CSS は完全にバニラ（`app/assets/stylesheets/application.css` 1枚＋インライン `style=` 3箇所）。スタイルが当たっているのは共通ヘッダー（#117）とホームのみ。

これからナビの `[+取り込み▼]` ドロップダウンや S8（明細一覧/編集）で UI を増やす直前であり、UI がまだ最小の今 Tailwind を導入すれば、以降を最初から Tailwind で作れて後追い移行の手戻りを避けられる。

現構成は Propshaft + importmap（Node/npm・`package.json` なし）で、開発は Docker Compose、CI は GitHub Actions（ネイティブ Ruby）。この構成を崩さずに導入できることを重視する。

---

## 論点と決定

- **gem は `tailwindcss-rails`（Tailwind v4 系）**: standalone CLI バイナリ方式で **Node/npm 不要**。Propshaft + importmap をそのまま維持し、`package.json` を追加しない。cssbundling-rails（Node 前提）は不採用。
- **本番ビルド**: 既存 `Dockerfile` の `assets:precompile` が Tailwind build を内包（gem が precompile にフック）。本番構成は変更不要。
- **CI（test ジョブ）**: `bin/rails tailwindcss:build` を `db:schema:load` の後・`rspec` の前に追加する。レイアウトが `tailwind` を参照するため、ビルド済み CSS が無いと Propshaft の MissingAsset でレイアウト描画 spec が全滅するため必須。
- **開発（Docker）**: 既存は単一プロセス（foreman/Procfile.dev なし）。watch は `docker-compose.override.yml` に **専用サービス `css`**（`rails tailwindcss:watch`）を追加して回す。foreman/`bin/dev` 依存は増やさない。
- **ビルド出力 `app/assets/builds/tailwind.css` は非コミット**（`.gitignore`）。生成は 開発=css サービス / CI=build ステップ / 本番=precompile が担う。
- **移行範囲は漸進**: 今回は共通クロム（レイアウト・ヘッダー・ホーム）＋インライン `style="color:red"` の3箇所のみ Tailwind 化してパターンを確立。各画面フォーム/一覧の本格スタイリングは後続スライスで行う。

---

## 影響・トレードオフ

- **Tailwind v4 の preflight** により素 HTML の既定スタイル（見出し・リスト・ボタン等）がリセットされ、未移行画面は一時的に今より簡素な見た目になる。機能への影響はなく、各スライスで整える前提。
- 既存 spec は class ではなく id・文言・リンク先を検証しているため、Tailwind 化（class 付与）による破壊はない想定。移行時に `id="global-nav"` や h1 文言などを保持する。

---

## スコープ外（後続）

- 各画面（transactions / categories / payment_methods / accounts / 認証系）の本格スタイリング。
- ナビ `[+取り込み▼]` ドロップダウン、アクティブ表示、モバイル用メニュー、ダークモード、デザインシステム化。
