# ADR-0048: 特別ルール（同名店舗を金額・日で判別する分類）

- ステータス: 承認済み
- 関連: [ADR-0047](0047-merchant-rules-and-recommendations-plan.md)（本 ADR が拡張）、#158

---

## 背景

ADR-0047 の店舗ルールは `店舗名 → カテゴリ` の 1 対 1。しかし実際のクレカ明細では、同じ店舗名でも中身が異なる支払いがまとまる（例: 「楽天SP」に複数のサブスク/購入が同名で並ぶ）。名前だけでは判別できず、日時は基本一緒だが金額が時々違うため正しく分類できない。

そこで、店舗名に加えて **金額（範囲）や毎月の日** を条件に持つ「特別ルール」を導入する。名前だけの店舗ルールより具体的なので優先して当て、外れたら店舗ルールへフォールバック、どれにも当たらなければ未分類のまま（＝要確認として人に返す）。一致時には任意の内容説明（note）を明細 `description` へ付記して「中身」を可視化する。

---

## 決定

### 分類の優先順位

**特別ルール（具体的）→ 店舗ルール（名前のみ・ADR-0047）→ 未分類**。

「当てられるものだけ当て、当てられないものは未分類のまま人に返す」方針。無理な推測でカテゴリを誤爆させない。

### 特別ルールの条件（v1）

1 ルール = **店舗名（必須）＋ 金額範囲 `amount_min`/`amount_max`（完全一致は min=max）＋ 任意で `day_of_month`**。すべて **AND** で評価する。

- **OR** はルール内では持たず、**同じカテゴリへ複数ルール**を作って表現する。
- **NOT・フル条件ビルダーは非スコープ**（将来検討）。
- 金額・日は生成カラム `effective_amount` / `effective_date` と照合する（アプリ全体の集計と揃える）。
- 判別条件（`amount_min`/`amount_max`/`day_of_month`）を最低 1 つ必須にする（名前だけなら店舗ルールと重複するため）。

### 複数一致の解決

正規化店舗名が一致し条件を満たす特別ルールが複数あるときは、**最も具体的なもの**を選ぶ（決定的）:
条件数が多い → 金額幅が狭い → `id` 昇順。

### 説明の付記（note）

特別ルールに任意の `note` を持たせ、一致した明細の `description` へ**追記**する（例: `楽天SP → 実体Netflix`）。原本 `merchant_name` は書き換えない。

### 取込時の自動適用（設定）

ADR-0047 の単一 bool `auto_apply_rules_on_import` を **種類別 2 bool** に分割する:

- `auto_apply_merchant_rules_on_import`（店舗ルール・旧 bool をリネーム）
- `auto_apply_special_rules_on_import`（特別ルール・default false）

取込時はこの 2 トグルで種類別に自動適用を制御する。**「更新実行」ボタンは両種を常に対象**にする（明示操作のため設定でゲートしない）。いずれも未分類の明細のみが対象で、手動分類は上書きしない（ADR-0047 の方針を踏襲）。

---

## データモデル

新規テーブル `special_rules`:

| カラム | 役割 |
|---|---|
| `user_id` | 所有者。FK `users` `ON DELETE CASCADE` |
| `merchant_name` | 正規化済み店舗名（`CategoryClassifier.normalize`）。not null |
| `amount_min` / `amount_max` | 金額範囲（int, nullable）。`effective_amount` と照合。完全一致=同値 |
| `day_of_month` | 毎月の日（int 1–31, nullable）。`effective_date.day` と照合 |
| `category_id` | 付与カテゴリ。複合FK `(user_id, category_id) → categories(user_id, id)`（#113 と同型） |
| `note` | 一致時に description へ付記する任意文字列（≤255） |

- モデル `SpecialRule`: `belongs_to :user, :category`、`normalizes :merchant_name`、検証は `MerchantClassification` と同型（`merchant_name` presence/length、`category_belongs_to_user`）に加え、`amount_min <= amount_max`（両方あるとき）、`day_of_month` 1..31、判別条件が最低 1 つ。

---

## 照合ロジック（`RuleMatcher`）

`RuleMatcher.new(user:, use_merchant:, use_special:)` を 1 回作り、明細ごとに `#match(merchant_name:, amount:, date:)` で `{category_id:, note:}` か `nil` を返す。

- 特別ルール（`use_special`）を先に評価 → 最具体を選ぶ。無ければ店舗ルール（`use_merchant`）へフォールバック。
- ルール群は初期化時に一括ロード（明細ループ内での N+1 回避）。
- `CategoryClassifier.normalize` を共有キーに使う。

適用点:

- **`RuleApplier`**（更新実行・両種常に true）: 未分類明細を `pluck(:id, :merchant_name, :effective_amount, :effective_date)` して解決。note 無しはカテゴリ別に `update_all`、note 有りは行単位で `category_id` ＋ `description` 追記。
- **`Imports::CsvImporter`**: `CategoryClassifier.category_ids_for` を `RuleMatcher` 経由へ置換し、取込設定の 2 bool で `use_merchant`/`use_special` を決める。note を description に追記して build。

---

## UI

- 専用の**特別ルール管理ページ**（`SpecialRulesController` + `resources :special_rules`）。多項目フォーム（店舗名・金額 min/max・日・カテゴリ・note）なので専用ページとし、カテゴリページ（店舗ルールの近く）から導線する。すべて `Current.user` スコープ・他人は 404。
- **アカウント設定**: 取込自動適用トグルを 2 つ（店舗ルール／特別ルール）に。未送信は false 化（ADR-0047 の `|| false` 方針踏襲）。

---

## 非スコープ

- ルール内の OR/NOT・フル条件ビルダー（OR は複数ルールで代替）。
- 特別ルールの「おすすめ」自動提案（金額クラスタリングは別途）。
- 手動まとめ入力（`ManualBulkImporter`）への自動適用。

---

## 代替案と却下理由

- **金額を完全一致のみ**: 「金額が時々違う」に対応できない → 範囲（min/max、完全一致は同値）を採用。
- **単一 bool のまま**: 店舗ルールと特別ルールを別々に制御したい要望に合わない → 種類別 2 bool。
- **ルール内 OR/NOT・条件ビルダー**: v1 には過剰。OR は複数ルールで足りる → 非スコープ。
