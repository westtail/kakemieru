# ADR-0018: DB設計レビュー（親子関係・冗長 ID・集計設計）

- 日付: 2026-04-11
- ステータス: 決定済み

---

## コンテキスト

実装開始前に DB 設計全体を改めてレビューし、以下の観点で妥当性を確認した。

1. 親子関係における ID の持ち方（正規化 vs 非正規化）
2. `transactions.user_id` を直接保持する設計の妥当性
3. 集計カラム（effective_date / effective_amount）の設計
4. 持たない判断をしたモデルの妥当性

---

## レビュー観点 1: 親子関係と ID の持ち方

### 基本原則

Rails（ActiveRecord）では `belongs_to :parent` を宣言した時点で、子テーブルに `parent_id` カラムが必要になる。これは規約であり、親子関係があれば**直近の親の id を子が持つのは当然の構造**。

```
User → PaymentMethod → Import → Transaction
         user_id         payment_method_id   import_id
                                             （直近の親）
```

### 今回の議論：祖先の id も持つか

直近の親だけ持つ（正規化）か、さらに上の祖先の id も冗長に持つか（非正規化）が設計上の選択肢。

```
# 正規化（辿る）
transaction.import.payment_method.user

# 非正規化（直接持つ）
transactions.user_id  ← 曾祖父を直接保持
```

---

## レビュー観点 2: transactions.user_id を直接持つ判断

### 採用した理由

**① セキュリティ（最重要）**

マルチテナント分離を DB レベルで保証するため。辿る設計だと JOIN の書き漏れで他ユーザーのデータが漏れるリスクがある。

```ruby
# 辿る設計：JOIN を1段忘れると情報漏洩
Transaction.joins(import: :payment_method)
           .where(payment_methods: { user_id: current_user.id })

# 直接持つ設計：WHERE 1行で完結・漏れようがない
current_user.transactions  # WHERE user_id = ? のみ
```

**② パフォーマンス**

月次集計・カテゴリ別集計など頻繁に走るクエリで JOIN が不要になる。`(user_id, effective_date)` の複合インデックス1本で高速に絞り込める。

**③ 経路変更への耐性**

Import や PaymentMethod の設計が変わっても、`user_id` を直接持つことで Transaction と User の関係は維持される。

### 非正規化のデメリットと対策

| デメリット | 対策 |
|---|---|
| 複数箇所に user_id が存在し不整合リスク | user_id は退会以外で変わらない設計にする |
| スキーマ変更時に影響範囲が広がる | user の所有権が変わる仕様を作らない |

### 採用しない典型ケース（参考）

- 所有者が変わりうるもの（リポジトリ移管、店舗譲渡など）
- 中間テーブルが「契約・所属」の意味を持つもの（Slack のワークスペースメンバーシップなど）
- 参照頻度が低く JOIN コストが問題にならないもの（社内申請フロー等）

---

## レビュー観点 3: user_id を持たない判断

KakeMieru 内でも以下のモデルは `user_id` を直接持たない。

| モデル | 持たない理由 |
|---|---|
| `budget_items` | 必ず BudgetTemplate 経由でアクセスする。単体検索の場面がない |
| `carryovers` | 必ず MonthlyBudget 経由でアクセスする。月次確定フロー内だけで使われる |

### 判断基準

```
「WHERE user_id = ? で直接検索・集計の起点になるか」
         ↓
    YES → user_id を直接持つ
    NO  → 辿れば十分
```

---

## レビュー観点 4: 集計カラム（generated columns）の設計

### effective_date / effective_amount

```sql
effective_date   GENERATED ALWAYS AS (COALESCE(date_override, date)) STORED
effective_amount GENERATED ALWAYS AS (COALESCE(amount_override, amount)) STORED
```

**問題**: ユーザーが日付や金額を上書きした場合、集計クエリが `date` と `date_override` のどちらを見るか統一されていないとバグになる。

**解決**: DB generated カラムとして `effective_date` / `effective_amount` を定義し、**集計・グラフ・レポートは必ずこちらを使う**ルールを徹底。`date` / `amount` は原本保持のみ。

---

## レビュー観点 5: ON DELETE ポリシー

| 親 → 子 | ポリシー | 理由 |
|---|---|---|
| users → 全テーブル | CASCADE | 退会時に全データ削除 |
| payment_methods → transactions | RESTRICT（明細あり）/ 物理削除（明細なし） | 明細がある場合はアーカイブのみ・明細なしなら物理削除可 |
| imports → transactions | 検討中 | 実装時に決定 |
| categories → transactions | 検討中 | 実装時に決定 |

---

## 結論

現行の DB 設計は以下の方針で統一されており、妥当と判断する。

- `transactions.user_id` の直接保持：セキュリティ・パフォーマンスの観点から採用
- `budget_items` / `carryovers` の非保持：単体検索の必要がないため不要
- `effective_date` / `effective_amount` の generated カラム：集計の一貫性を DB レベルで保証

詳細なテーブル定義は [DATABASE_DESIGN.md](../DATABASE_DESIGN.md) を参照。
