# ADR-0042: transactions の複合FK（DB層マルチテナント保護）と structure.sql 導入

- 日付: 2026-08-23
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0027 S7 transactions](0027-s7-transactions-plan.md) / [ADR-0041 user FK CASCADE](0041-user-fk-on-delete-cascade-plan.md) / DATABASE_DESIGN
- 対象 Issue: #113

---

## コンテキスト

S7（ADR-0027）では transactions のテナント整合（category / payment_method が同一ユーザーか）をアプリ層バリデーション + コントローラの `Current.user` スコープで担保し、DB 層の複合FKは「schema.rb では表現できない」ため見送っていた。DATABASE_DESIGN は複合FKによる多層防御をフェーズ1から求めている。本 ADR で structure.sql へ切替え、複合FKを追加する。#110（user FK CASCADE, #142）はマージ済みで、本 ADR はその上に載る。

---

## 決定

### 1. スキーマ形式を structure.sql（`:sql`）へ切替

- `config.active_record.schema_format = :sql`。`db/schema.rb` を廃止し `db/structure.sql`（pg_dump 生成）で管理する。
- 複合FK・列指定 `ON DELETE SET NULL`・部分 UNIQUE インデックスなど、Ruby 形式では失われる制約を CI/テスト DB まで含めて再現するため。
- CI の `bin/rails db:create db:schema:load` は `schema_format = :sql` を尊重して structure.sql をロードするため、**ci.yml の変更は不要**。`db:test:prepare` / `maintain_test_schema!` も structure.sql を使う。

### 2. transactions に複合FKを追加（生 SQL マイグレーション）

複合FKのターゲットには UNIQUE 制約が必要。既存の unique **インデックス** `index_{categories,payment_methods}_on_user_id_and_id` を `ADD CONSTRAINT ... UNIQUE USING INDEX` で unique **制約**へ昇格する（再スキャンなし）。

既存の単一列FK（`category_id → categories(id)` / `payment_method_id → payment_methods(id)`）を削除し、複合FKへ置き換える:

- `(user_id, category_id) → categories(user_id, id)` … `ON DELETE SET NULL (category_id)`。
  - カテゴリ削除時、`category_id` だけ NULL 化（未分類）。`user_id` は NOT NULL のため**列指定** SET NULL を使う（**PG15+** 機能。dev 16 / CI 17 で対応。本番 Fly Postgres も同世代前提）。
  - `category_id` が NULL の行は MATCH SIMPLE により制約対象外（未分類を許容）。
- `(user_id, payment_method_id) → payment_methods(user_id, id)` … `ON DELETE` 無指定（**NO ACTION**）。
  - `payment_method_id` は NOT NULL のため常に検査。物理削除はアプリ層（明細あり→アーカイブ）で先に回避する。
  - 元の単一列FK（NO ACTION）と同じ削除挙動を維持する。RESTRICT にしないのは、user 削除の CASCADE（#110）で payment_methods と transactions が同時削除される経路を、NO ACTION の文末遅延評価で阻害しないため（RESTRICT は即時評価で失敗し得る）。

`user_id → users(id)`（CASCADE・#110）と `import_id → imports(id)`（RESTRICT）は変更しない。

### 4. マルチDB（cache 接続）の schema_format 波及を遮断

`schema_format` はグローバル設定のため、production の `cache` 接続（solid_cache スキャフォールド）が存在しない `db/cache_structure.sql` を要求し得る。`solid_cache_entries` は primary（structure.sql）で管理し cache 接続は同一物理 DB を参照するだけなので、`config/database.yml` の cache に `database_tasks: false` を付け、rake db タスクの対象から外す（cache の読み書きには影響しない）。`db/cache_schema.rb` は以後不使用（inert）。

### 3. アプリ層バリデーションは維持

Transaction のテナント整合バリデーション（category / payment_method が同一 user か）は多層防御として残す。DB 複合FKと二層で守る。

---

## 影響・リスク

- **PG15+ 依存**: 列指定 `ON DELETE SET NULL` は PostgreSQL 15 以上が必須。dev 16.14 / CI 17 で確認済み。本番が 15 未満の場合は適用不可のため、デプロイ前に本番 PG バージョンを確認する。
- structure.sql は環境差（拡張・照合順序）を含み得るが、本プロジェクトは単純構成のため差分は小さい想定。
- 既存データは全て `(user_id, category_id)` がテナント整合済み（アプリ層担保）のため、複合FK 追加時の検証は通る。

## スコープ外

- imports / merchant_classifications 等への複合FK 拡張（今回は transactions のみ）。
- 複合FK の参照側インデックス追加（カテゴリ削除は稀・小規模のため）。将来必要になれば別途。
