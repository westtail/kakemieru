# CLAUDE.md

Claude Code がこのリポジトリで作業する際の指示書。

---

## プロジェクト概要

**KakeMieru（家計見える）** — クレジットカード明細 CSV をアップロードして収支をグラフで可視化する家計簿 Web アプリ。

- Rails 8 / PostgreSQL / Hotwire / Docker / Fly.io
- 詳細は [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) を参照

---

## 開発環境

Docker Compose で起動する。ローカルに Ruby/Rails は不要。

```bash
docker compose up -d          # 起動
docker compose run --rm web <コマンド>   # 任意のコマンド実行
docker compose run --rm web bundle exec rspec   # テスト実行
docker compose run --rm web bin/rails console   # コンソール
```

---

## テスト

- フレームワーク: **RSpec + FactoryBot + Shoulda Matchers**（ADR-001 で決定）
- カバレッジ目標: 80% 以上
- TDD: テストを先に書く（RED → GREEN → REFACTOR）
- テストファイルは `spec/` 配下に配置

```bash
docker compose run --rm web bundle exec rspec                       # 全テスト
docker compose run --rm web bundle exec rspec spec/requests/        # 特定ディレクトリ
docker compose run --rm web bundle exec rspec --format documentation
```

---

## 開発フロー

Issue → ブランチ → 実装（TDD） → PR → マージ

詳細は [docs/DEVELOPMENT_FLOW.md](docs/DEVELOPMENT_FLOW.md) を参照。

---

## コミット規則

```
feat:     新機能
fix:      バグ修正
refactor: リファクタリング
test:     テスト追加・修正
docs:     ドキュメント
ci:       CI/CD 変更
chore:    その他
```

---

## 意思決定記録（ADR）

`decisions/` に保存。技術方針を変更するときは先に ADR を書く。

- [ADR-001](decisions/ADR-001-testing-framework.md) — テストフレームワーク（RSpec 採用）
