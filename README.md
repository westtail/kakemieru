# KakeMieru（家計見える）

クレジットカード明細 CSV をアップロードして収支をグラフで可視化する家計簿 Web アプリ。

- Rails 8 / PostgreSQL / Hotwire / Docker / Fly.io
- 認証は Rails 8 Built-in Authentication（メール + パスワード）

## 前提条件

- Docker / Docker Compose v2（ローカルに Ruby/Rails は不要）

## セットアップ・起動

```bash
# クローン
git clone https://github.com/westtail/kakemieru.git
cd kakemieru

# 環境変数（POSTGRES_PASSWORD を設定）
cp .env.example .env

# ビルド
docker compose build

# 起動（web / db / chrome が立ち上がる）
docker compose up -d

# DB 準備（初回のみ・作成 + マイグレーション）
docker compose exec web bin/rails db:prepare
```

ブラウザで http://localhost:3000 を開く（未ログインは `/sign_in` にリダイレクト）。
`/sign_up` からアカウント登録すると、そのままログインしてダッシュボードに入れる。

### 主な画面（認証）

| パス | 内容 |
|---|---|
| `/sign_up` | ユーザー登録 |
| `/sign_in` | ログイン |
| `/sign_out` | ログアウト（DELETE） |
| `/passwords/new` | パスワードリセット申請 |
| `/account` | アカウント設定（メール・パスワード変更） |
| `/account/delete` | 退会 |

## テスト

テストは Docker コンテナ内で実行する（`chrome` サービスが起動している必要がある = `docker compose up -d` 済み）。

```bash
# 全テスト（ユニット / リクエスト / システム(E2E)）
docker compose exec web bundle exec rspec

# 種別ごと
docker compose exec web bundle exec rspec spec/models      # モデル（ユニット）
docker compose exec web bundle exec rspec spec/requests     # コントローラ（リクエスト）
docker compose exec web bundle exec rspec spec/features      # E2E（実ブラウザ・要 chrome）

# ドキュメント形式で詳細表示
docker compose exec web bundle exec rspec --format documentation
```

- カバレッジは実行のたび `coverage/index.html` に出力される（目標 80%。下回ると警告）。
- Lint: `docker compose exec web bin/rubocop`
- セキュリティ静的解析: `docker compose exec web bin/brakeman --no-pager`

### E2E（システムスペック）について

`spec/features/` は Capybara + Cuprite で別コンテナの Chrome（`docker compose up -d` で起動）を操作する。追加設定は不要。詳細は [ADR-0023](docs/decisions/0023-e2e-test-environment.md) を参照。

## 開発の便利機能

- **送信メールの確認**: 開発環境ではメール（パスワードリセット等）が実送信されず、
  http://localhost:3000/letter_opener で内容を確認できる（letter_opener_web）。
- **Rails コンソール**: `docker compose exec web bin/rails console`

## 停止

```bash
docker compose down
```

## ドキュメント

- [docs/PROJECT_ABOUT.md](docs/PROJECT_ABOUT.md) — 全体像・技術スタック・要件
- [docs/DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) — 開発フロー
- [docs/design/](docs/design/) — DB / 画面 / 認証などの設計
- [docs/decisions/](docs/decisions/) — ADR（意思決定記録）

## 本番インフラのセットアップ

Fly.io・GitHub Actions・ブランチ保護などの初回設定は [docs/infra/INITIAL_SETUP.md](docs/infra/INITIAL_SETUP.md) を参照。
