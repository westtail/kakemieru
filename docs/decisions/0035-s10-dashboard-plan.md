# ADR-0035: S10 ダッシュボード（Stimulus + Chart.js）の実装計画

- 日付: 2026-08-17
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0034 サマリー API](0034-s9-summary-api-plan.md) / [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md) / [SUMMARY_API.md](../design/SUMMARY_API.md)
- 対象 Issue: #48（ダッシュボード UI）

---

## コンテキスト

ログイン後トップ `/`（`home#index`）を月次の収支ダッシュボードにする。月切り替えで `GET /transactions/summary`（#45）を fetch し、Chart.js でカテゴリ別円グラフ・支出合計・未分類バッジを描画する。設計は SCREEN_DESIGN のダッシュボード節。

---

## 論点と決定

- **サマリー API に `count` を追加**（#45 の契約を拡張）: SCREEN_DESIGN の「未分類 N件」バッジに件数が必要。`MonthlySummary` は amount のみだったので、各カテゴリに `count` を持たせ `categories: [{ id, name, amount, count }]` にする。`total` は据え置き。`SUMMARY_API.md` と spec も更新。
- **Chart.js は importmap で自己完結配信**（Node 不使用）: `bin/importmap pin chart.js` で `vendor/javascript` に vendor 取り込み（chart.js 4.5.1 + @kurkle/color）。Propshaft 配信・CDN 非依存。
- **初期描画も Stimulus fetch**: `home#index` は薄いシェル。初期月（URL の `?month=` or 当月）を data 属性で渡し、Stimulus が connect で fetch → 描画。集計はサーバの summary API に一本化。
- **pushState は fetch 成功後のみ**（SCREEN_DESIGN 準拠）。ローディング中・失敗時は URL を変えない。
- **未認証**: 既存の `require_authentication` で `/sign_in` へリダイレクト（ダッシュボードは HTML ページ。JSON API の #45 が 401 を返すのとは別）。

---

## 実装

- **`Transactions::MonthlySummary`**: `group(:category_id).count` を併用し各カテゴリに `count` を付与。
- **`config/importmap.rb`**: `pin "chart.js"` / `pin "@kurkle/color"`（vendor）。
- **`app/javascript/controllers/dashboard_controller.js`**（新規）: 月切り替え・fetch・Chart.js 円グラフ・合計/未分類バッジ更新・pushState。
- **`app/views/home/index.html.erb`**: ダッシュボードのシェル（月ナビ・合計・canvas・未分類バッジ・取り込み/手動ボタン）。
- **`home_controller#index`**: 薄いまま（初期 month をビューへ）。

---

## スコープ外

- 収入/支出の内訳区分・予算比較・期間集計（フェーズ2）。Chart.js の詳細スタイリング。
