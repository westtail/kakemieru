# サマリー API 設計（`GET /transactions/summary`）

ダッシュボード（#48）が消費する月次集計 JSON を返す読み取り専用エンドポイント。

## エンドポイント

```http
GET /transactions/summary?month=YYYY-MM
```

- **GET 専用**。書き込み系アクションはこのエンドポイント／コントローラに追加しない。
- **認証必須**。未ログインは `401 Unauthorized`（HTML のようにログイン画面へリダイレクトしない）。
- `month` 省略・不正形式（`YYYY-MM` でない）は `422 Unprocessable Entity`。

## パラメータ

| 名前 | 必須 | 形式 | 説明 |
|---|---|---|---|
| `month` | 必須 | `YYYY-MM` | 集計対象月。`effective_date` がこの月の明細を対象。 |

## レスポンス（200）

```json
{
  "month": "2026-04",
  "total": 12300,
  "categories": [
    { "id": 1, "name": "食費", "amount": 8000, "count": 12 },
    { "id": 3, "name": "交通費", "amount": 3000, "count": 4 },
    { "id": null, "name": "未分類", "amount": 1300, "count": 3 }
  ],
  "monthly_totals": [
    { "month": "2025-11", "total": 9000 },
    { "month": "2025-12", "total": 11000 },
    { "month": "2026-01", "total": 0 },
    { "month": "2026-02", "total": 8000 },
    { "month": "2026-03", "total": 10500 },
    { "month": "2026-04", "total": 12300 }
  ],
  "recent_average": { "window": 3, "months": 3, "baseline": 10000, "diff": 2300, "rate": 23.0 },
  "monthly_average": {
    "months": 6,
    "overall": 9500,
    "categories": [
      { "id": 1, "name": "食費", "average": 7000 },
      { "id": 3, "name": "交通費", "average": 2500 }
    ]
  }
}
```

- `total`: 対象月の `effective_amount` の**符号付き合計**（返金明細のマイナスも反映した純額）。
- `categories`: カテゴリ別の `effective_amount` 合計（`amount`）と**明細件数**（`count`）。**amount 降順**。**未分類**（`id: null`, `name: "未分類"`）も含む。ダッシュボードの「未分類 N件」バッジは未分類の `count` を使う。
- `monthly_totals`（#153）: `month` を末尾に**直近6ヶ月**の月別支出合計を**古い順**で。データの無い月は `total: 0`。ダッシュボードの月別推移グラフに使う（`Transactions::MonthlyTotals`）。
- `recent_average`（#163）: 当月と**直前 `window` ヶ月の平均**の比較（`Transactions::RecentAverageComparison`）。`window`（比較窓＝3）・`months`（そのうちデータのある月数＝分母）・`baseline`（直近平均）・`diff`（当月 − 基準）・`rate`（増減率%・小数第1位）。基準はデータのある月のみで平均し当月は含めない。直近にデータが無ければ `rate` は `null`。
- `monthly_average`（#155）: **全期間**の月平均支出（`Transactions::MonthlyAverage`）。`months`（明細のある月数＝分母）・`overall`（全体の月平均）・`categories`（カテゴリ別の月平均・降順）。分母は空の月を除いた「明細のある月数」で全体・カテゴリ別とも共通。各値は四捨五入するため、カテゴリ別の合計と全体は数円ずれ得る。月に依存しない値。
- 集計対象は `deleted_at IS NULL`（取り消し済みは除外）かつ本人の明細のみ。

## エラー

| 状況 | ステータス | ボディ |
|---|---|---|
| 未ログイン | `401` | （空） |
| `month` 不正・欠落 | `422` | `{ "error": "月の形式が不正です（YYYY-MM）" }` |

## CSRF ポリシー（#14）

- 本エンドポイントは JSON を返す **読み取り専用の専用コントローラ `Transactions::SummariesController`** に実装し、`protect_from_forgery with: :null_session` を適用する。
- `null_session` は**コントローラ全体**の CSRF 戦略を変えるため、書き込みアクションを持つ `TransactionsController` には適用しない。GET 専用に隔離することで、将来の書き込み追加時に CSRF 防御が失われるのを防ぐ。
- 書き込み系（作成・更新・削除・カテゴリ即時変更）は従来どおり通常の CSRF 保護（`:exception`）を維持する。書き込みが必要になった場合もこのコントローラには足さず、別コントローラで通常保護のまま実装する。
