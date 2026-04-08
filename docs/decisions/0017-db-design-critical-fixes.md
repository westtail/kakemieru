# ADR-0017: DB設計の重要修正（マルチテナント・カテゴリ・集計）

- 日付: 2026-04-08
- ステータス: 決定済み

---

## コンテキスト

DB設計レビューにより、実装前に対処すべき CRITICAL な問題が4つ発見された。
本 ADR はそれらの修正方針を記録する。

---

## CRITICAL 1: categories の設計矛盾

### 問題

`DATABASE_DESIGN.md` と `ADR-0015` でカテゴリの所有モデルが矛盾していた。
- DATABASE_DESIGN.md：`user_id = NULL` = 共通カテゴリ（参照共有モデル）
- ADR-0015：登録時にテンプレートをコピーしてユーザーごとの行を作る（コピー方式）

### 決定：コピー方式に統一

- `categories.user_id` は **NOT NULL**（必ずユーザーに紐づく）
- システムテンプレートは `category_templates` という**別テーブル**に切り出す
- 新規ユーザー登録時に `category_templates` の内容を `categories` にコピーして初期セットを生成
- コピー後はユーザーが自由に名前変更・追加・削除できる

```
category_templates（システム管理・不変）
  category_key  "food" / "transport" / "daily" など
  name          "食費" / "交通費" / "日用品" など

  ↓ 新規登録時にコピー

categories（ユーザーごと）
  user_id       NOT NULL
  category_key  テンプレートとの紐づけキー（独自カテゴリは NULL）
  name          ユーザーが自由に変更可（"食費" → "飲食費" など）
```

### 理由

- 「食費 vs 飲食費」のように個人の好みで名前を変えられる
- 他ユーザーへの影響がない
- `category_key` を持つことで共有マッピング（merchant_classifications）との紐づけが可能

---

## CRITICAL 2: マルチテナント分離の穴

### 問題

`transactions` は `payment_method_id → user_id` の2段階で所有者を辿る設計だった。
`category_id` / `import_id` は別経路で `user_id` に辿るため、3経路の整合性をアプリコードだけで保証する必要があり、バグ時に別ユーザーのデータが混入するリスクがあった。

### 決定：transactions に user_id を直接保持

```
transactions
  user_id   直接保持（非正規化）
```

- `WHERE user_id = current_user.id` だけで安全に絞り込める
- JOIN なしで所有者確認ができる
- アプリコードのバグによるテナント間データ混入を防止

### 理由

- 個人向け家計簿として最低限のセキュリティ保証をDBに下ろす
- 将来的に複合FK（`FOREIGN KEY (user_id, category_id) REFERENCES categories(user_id, id)`）を追加することでより強固にできる（フェーズ1では不採用・拡張候補）

---

## CRITICAL 3: date_override による集計ズレ

### 問題

ユーザーが明細の日付を修正（`date_override`）した場合、集計クエリが `date` と `date_override` のどちらを見るか統一されていなかった。
例：3月31日の明細を4月1日に修正した場合、`date` で集計すると3月に入り、正しくない結果になる。

### 決定：生成カラム effective_date / effective_amount を追加

```sql
effective_date   GENERATED ALWAYS AS (COALESCE(date_override, date)) STORED
effective_amount GENERATED ALWAYS AS (COALESCE(amount_override, amount)) STORED
```

- 集計・グラフ・レポートは全て `effective_date` / `effective_amount` を使う
- `date` / `amount` は原本として保持するが集計には使わない
- インデックスも `effective_date` に張る

### 理由

- 集計ロジックを1箇所に統一し、書き忘れによるバグを根絶
- `COALESCE` を毎回書く必要がなくなる

---

## CRITICAL 4: ON DELETE ポリシーの定義

### 決定事項

| 親 → 子 | ポリシー | 理由 |
|---------|---------|------|
| users → 全テーブル | CASCADE | 退会時に全データ削除。データ残留は利用規約上アウト |
| payment_methods → transactions | RESTRICT | ソフトデリートで対応するため物理削除は起きない |
| imports → transactions | 検討中 | |
| categories → transactions | 検討中 | |

### payment_methods の削除ポリシー

物理削除ではなくソフトデリート（`archived_at`）を採用。

- 削除操作時は大きな警告を表示（「過去の明細データが参照できなくなります」）
- 削除後1週間は `archived_at` フラグのみ立てて復元可能
- 1週間後に完全削除バッチを実行

### 理由

- 支払い手段を削除しても過去の明細は `payment_method_id` で参照されているため物理削除すると履歴が壊れる
- ユーザーが誤って削除した場合の救済手段を設ける

---

## 保留事項

- imports / categories の削除ポリシー（実装時に決定）
- マッピング変更時の過去明細の扱い（バージョン管理 vs スナップショット）

---

## 結果

詳細なテーブル定義は [DATABASE_DESIGN.md](../DATABASE_DESIGN.md) を参照。
