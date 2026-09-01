# ADR-0047: 月別集計グラフ（支出推移）

- 日付: 2026-08-29
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0034 サマリー API](0034-s9-summary-api-plan.md) / [ADR-0035 ダッシュボード](0035-s10-dashboard-plan.md)
- 対象 Issue: #153

---

## コンテキスト

ダッシュボードは単月のカテゴリ別円グラフのみで、月をまたいだ支出推移が見えない（PROJECT_ABOUT フェーズ1「月別集計グラフ」未）。#154 前年同月比・#155 月平均も同じサマリー API/ダッシュボードを共有するため、本 issue で「月別推移」を土台として入れる。

## 決定

- **直近6ヶ月の月別支出合計**を棒グラフでダッシュボードに追加する（カテゴリ別内訳は載せず合計のみ・シンプル優先）。
- 集計は新サービス **`Transactions::MonthlyTotals`**（`user:, month:, count: 6`）。`effective_amount` + `not_deleted` を `date_trunc('month', effective_date)` で月ごとに合計し、**データの無い月は 0 で埋めて** 古い順の配列 `[{ month: "YYYY-MM", total: }, ...]` を返す。
- **既存サマリー API を拡張**: `GET /transactions/summary?month=` の JSON に `monthly_totals` を追加（ダッシュボードの既存 fetch がそのまま取得）。月ナビで推移窓もその月を末尾にスライドする。
- ダッシュボードの `dashboard_controller.js` に棒グラフを追加（Chart.js の BarController 等を register）。円グラフと同じ月次 fetch で両方描画。

## スコープ外

- カテゴリ別の積み上げ（合計のみ）。折れ線/期間可変（6ヶ月固定）。前年同月比（#154）・月平均（#155）は本 issue の API 拡張の上に別途。
