# ADR-0046: カテゴリ自動分類の学習（手動分類→次回取込に反映）

- 日付: 2026-08-29
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0015 カテゴリ分類方針](0015-category-classification-strategy.md) / [ADR-0044 明細ソート](0044-transaction-sort-plan.md) / #113 複合FK
- 対象 Issue: #152

---

## コンテキスト

`CategoryClassifier`（読み取り側）は CSV 取込に配線済みだが、`merchant_classifications` に**書き込む経路が無く辞書が空**のため自動分類が実質未稼働。設計（CATEGORY_CLASSIFICATION.md）のフェーズ1は「手動分類→保存→次回同店舗を自動分類」の学習方式。実装済みスキーマは全ユーザー共通の `merchant_name → category_key` だったが、独自カテゴリ（category_key=NULL）を学習できず、テナント分離もされないため、**ユーザー個別（user_id + category_id）** に作り替える（テーブルは空なのでデータ移行不要）。

## 決定

- **スキーマ**: `merchant_classifications` を `(user_id, merchant_name)` 一意のユーザー個別に。`category_key` を廃し `category_id` を持つ。`user_id → users` と**複合FK `(user_id, category_id) → categories(user_id, id)`** をともに `ON DELETE CASCADE`（テナント整合を DB 層でも担保・#113 と同型）。独自カテゴリも学習できる。
- **学習**: カテゴリを手動付与したとき（`categorize` / `categorize_all` / 明細編集の `update`）に、店舗名（`CategoryClassifier.normalize` で正規化）→ category_id を `source: "user_manual"` で **upsert**（`MerchantClassification.learn_all`・`upsert_all` で一括・N+1回避・並行学習でも RecordNotUnique にならない）。
- **忘却はしない（積み上げのみ）**: 明細を未分類に戻しても店舗の学習ルールは消さない。1件の未分類化が店舗全体の自動分類を止める副作用を避けるため（レビュー指摘）。ルールを変えたいときは別カテゴリに付け直す（upsert で上書き）。
- **読み取りの簡素化**: `CategoryClassifier.category_ids_for` は `user.merchant_classifications` から `merchant_name → category_id` を直接引く（category_key→id の解決が不要に）。csv_importer は変更なし。
- CATEGORY_CLASSIFICATION.md と実装のズレ（全共通 vs ユーザー個別）を、ユーザー個別に寄せて解消する。

## スコープ外

- AI 深夜バッチ分類（フェーズ2）・共有マッピング（フェーズ3）・confidence カラム。
- merchant_name 編集時の能動的な再分類サジェスト（編集で category を選べば学習される）。
