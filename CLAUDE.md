# CLAUDE.md

Claude Code がこのリポジトリで作業する際の指示書。

---

## プロジェクト概要

**KakeMieru（家計見える）** — クレジットカード明細 CSV をアップロードして収支をグラフで可視化する家計簿 Web アプリ。

- Rails 8 / PostgreSQL / Hotwire / Docker / Fly.io
- 詳細は [docs/PROJECT_ABOUT.md](docs/PROJECT_ABOUT.md) を参照

---

## 開発環境

Docker Compose で起動する。ローカルに Ruby/Rails は不要。

```bash
docker compose up -d          # 起動
docker compose exec web <コマンド>        # 任意のコマンド実行
docker compose exec web bundle exec rspec   # テスト実行
docker compose exec web bin/rails console   # コンソール
```

---

## テスト

- フレームワーク: **RSpec + FactoryBot + Shoulda Matchers**（ADR-001 で決定）
- カバレッジ目標: 80% 以上
- TDD: テストを先に書く（RED → GREEN → REFACTOR）
- テストファイルは `spec/` 配下に配置

```bash
docker compose exec web bundle exec rspec                       # 全テスト
docker compose exec web bundle exec rspec spec/requests/        # 特定ディレクトリ
docker compose exec web bundle exec rspec --format documentation
```

---

## 開発フロー

Issue → ブランチ → 実装（TDD） → PR → マージ

詳細は [docs/DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) を参照。

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

## 設計ドキュメント

実装時は以下を参照すること。

- [PROJECT_ABOUT.md](docs/PROJECT_ABOUT.md) — 全体像・技術スタック・機能要件・非機能要件
- [DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) — 開発フロー詳細
- [DATABASE_DESIGN.md](docs/design/DATABASE_DESIGN.md) — DB設計
- [SCREEN_DESIGN.md](docs/design/SCREEN_DESIGN.md) — 画面設計
- [AUTHENTICATION.md](docs/design/AUTHENTICATION.md) — 認証設計
