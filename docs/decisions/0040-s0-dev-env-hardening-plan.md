# ADR-0040: S0 開発環境整備（annotate / seeds / bundler-audit）

- 日付: 2026-08-21
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0005 CI/CD](0005-cicd-pipeline.md) / [ADR-0024 カテゴリ分類](0024-s3-categories-plan.md)
- 対象 Issue: #57

---

## コンテキスト

開発効率とセキュリティ品質を上げる開発環境整備をまとめて行う。#57 の4項目のうち、
**letter_opener（`letter_opener_web` + development.rb 設定）と brakeman（CI `scan_ruby`）は既に導入済み**。
残る **annotate / 開発用 seeds / bundler-audit** を対応する。

---

## 論点と決定

- **annotate は `annotaterb` を採用**: 従来の `annotate`（ctran/annotate_models）は 2022 年以降ほぼ更新が止まり Rails 8 での動作が不安定。維持フォークの `annotaterb`（drwl/annotaterb）は Rails 8 対応で active。`bin/rails g annotate_rb:install` で `.annotaterb.yml` と rake フック（`lib/tasks/annotate_rb.rake`）を生成し、`db:migrate` 後にモデルへスキーマコメントを自動追記する。対象はモデルのみ（factory/spec への注釈は無効）。development グループに `require: false` で追加。
- **seeds は development 限定のサンプルデータ**: `db/seeds.rb` は全環境で冪等。既存のカテゴリテンプレート投入はそのまま残し、`Rails.env.development?` のときだけサンプルの「ユーザー・支払方法・カテゴリ・明細（当月/先月）」を追加する。ユーザーの初期データは本番登録と同じ経路（`Category.copy_templates_to` / `PaymentMethod.create_default_for`）で作り、実挙動と乖離させない。明細は自然キーが無いため「ユーザーに明細が無いときだけ投入」で冪等化する。
- **bundler-audit は CI の独立ジョブ**: `bundler-audit` gem を development/test に追加し、`.github/workflows/ci.yml` に `scan_deps` ジョブを足して `bundle exec bundler-audit check --update` を実行する。既存の `scan_js`（importmap audit）と対をなす依存脆弱性チェック。

---

## 実装

- `Gemfile`: development に `annotaterb`、development/test に `bundler-audit`（ともに `require: false`）。
- `.annotaterb.yml` / `lib/tasks/annotate_rb.rake`: `annotate_rb:install` ジェネレータの生成物。
- 各 `app/models/*.rb`: `annotaterb models` によるスキーマコメント追記。
- `.github/workflows/ci.yml`: `scan_deps` ジョブ追加。
- `db/seeds.rb`: development 限定のサンプルデータを冪等に追加。

## 完了条件

- `/letter_opener` でメール確認（既存・維持）。
- `bin/rails db:seed` でサンプルデータが冪等に投入される。
- CI の brakeman（既存）・bundler-audit（新規）が GREEN。
- `db:migrate` でモデルにスキーマコメントが自動追記される。

## スコープ外

- production への seed 投入（本番はマイグレーションでテンプレ投入・ADR-0024）。
- annotate の factory/spec 注釈、routes 注釈。
