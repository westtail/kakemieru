# KakeMieru

クレジットカード明細 CSV をアップロードして収支を可視化する家計簿 Web アプリ。

## 前提条件

- Docker / Docker Compose v2

## 開発環境の起動

```bash
# リポジトリをクローン
git clone https://github.com/westtail/kakemieru.git
cd kakemieru

# 環境変数ファイルを準備
cp .env.example .env
# .env を編集して POSTGRES_PASSWORD を設定

# イメージをビルド
docker compose build

# 起動 + DB 初期化（初回のみ）
docker compose up -d
docker compose exec web bin/rails db:create db:migrate
```

ブラウザで http://localhost:3000 を開く。

## テスト

```bash
docker compose exec web bundle exec rspec
```

## 停止

```bash
docker compose down
```

## 本番インフラのセットアップ

Fly.io・GitHub Actions・ブランチ保護などの初回設定は [docs/infra/INITIAL_SETUP.md](docs/infra/INITIAL_SETUP.md) を参照。
