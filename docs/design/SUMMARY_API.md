# サマリー API 設計

最終更新: 2026-04-12

---

## 概要

ダッシュボードのグラフ・合計額を Stimulus + fetch で取得するための JSON API。

---

## エンドポイント

```
GET /transactions/summary?month=2026-04
```

- `month` パラメータ: `YYYY-MM` 形式。省略時は当月
- 認証必須（未ログインは 401）
- レスポンス: JSON

---

## DB への影響

**なし。** 既存のスキーマで全て取得できる。

```ruby
# 実行されるクエリのイメージ
current_user.transactions
  .in_month(year, month)                    # WHERE user_id=? AND deleted_at IS NULL AND effective_date BETWEEN ...
  .joins("LEFT JOIN categories ON categories.id = transactions.category_id")
  .group("categories.id, categories.name")
  .sum(:effective_amount)
# → インデックス (user_id, deleted_at, category_id, effective_date) がそのまま使われる
```

---

## レスポンス形式

### 成功時（200）

```json
{
  "month": "2026-04",
  "total": 128400,
  "categories": [
    { "id": 1,   "name": "食費",   "amount": 45000 },
    { "id": 2,   "name": "交通費", "amount": 12000 },
    { "id": 3,   "name": "日用品", "amount": 18000 },
    { "id": null,"name": "未分類", "amount": 5000  }
  ]
}
```

**フィールドの仕様**

| フィールド | 型 | 説明 |
|---|---|---|
| `month` | string | リクエストした月（YYYY-MM） |
| `total` | integer | 月の支出合計（円） |
| `categories[].id` | integer \| null | カテゴリID。未分類は `null` |
| `categories[].name` | string | カテゴリ名。未分類は `"未分類"` 固定 |
| `categories[].amount` | integer | カテゴリ別支出合計（円） |

- `categories` は `amount` の降順で返す
- 金額ゼロのカテゴリは含めない
- グラフの色は **フロント側で決める**（カテゴリIDをキーに Stimulus コントローラー内で固定色マップを保持）

### エラー時

| ケース | ステータス | ボディ |
|---|---|---|
| 未ログイン | 401 | `{ "error": "Unauthorized" }` |
| `month` パラメータ不正 | 422 | `{ "error": "month の形式が不正です（YYYY-MM）" }` |
| 将来存在しない月（サーバーエラー） | 500 | `{ "error": "Internal Server Error" }` |

---

## コントローラー実装方針

```ruby
class TransactionsController < ApplicationController
  # GET /transactions/summary
  def summary
    year, month = parse_month(params[:month])  # "2026-04" → [2026, 4]

    rows = current_user.transactions
                       .in_month(year, month)
                       .joins("LEFT JOIN categories ON categories.id = transactions.category_id")
                       .group("categories.id, categories.name")
                       .sum(:effective_amount)
    # rows: { [1, "食費"] => 45000, [nil, nil] => 5000, ... }

    categories = rows.map do |(id, name), amount|
      { id: id, name: name || "未分類", amount: amount }
    end.sort_by { |c| -c[:amount] }

    render json: {
      month: params[:month],
      total: categories.sum { |c| c[:amount] },
      categories: categories
    }
  end

  private

  def parse_month(str)
    date = Date.strptime(str, "%Y-%m")
    [date.year, date.month]
  rescue ArgumentError, TypeError
    render json: { error: "month の形式が不正です（YYYY-MM）" }, status: :unprocessable_entity
    nil
  end
end
```

---

## Stimulus コントローラーとの接続

```javascript
// dashboard_controller.js（実装時の参考）
async switchMonth(month) {
  const res = await fetch(`/transactions/summary?month=${month}`, {
    headers: { "Accept": "application/json" }
  })
  if (!res.ok) {
    // エラー表示（URLは変更しない）
    return
  }
  const data = await res.json()
  this.updateTotal(data.total)
  this.updateChart(data.categories)
  history.pushState({}, "", `/?month=${month}`)  // fetch 完了後に URL 更新
}
```

---

## グラフの色マップ（フロント側）

カテゴリIDに対して固定色を割り当てる。DB には持たない。

```javascript
const CATEGORY_COLORS = {
  default: [
    "#4F81BD", "#C0504D", "#9BBB59", "#8064A2",
    "#4BACC6", "#F79646", "#2C4770", "#772C2C"
  ]
}
// categories 配列の index で循環して色を割り当てる
```
