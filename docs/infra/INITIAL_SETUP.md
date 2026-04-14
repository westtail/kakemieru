# 初期セットアップ手順

最終更新: 2026-03-23

---

## 概要

このドキュメントは、KakeMieru の開発環境を0から構築し、本番デプロイまでを通す手順を定義する。
一度完了すれば以降は [DEVELOPMENT_GUIDE.md](../DEVELOPMENT_GUIDE.md) に従って開発する。

---

## 前提条件

- Docker / Docker Compose v2 がインストール済み
- GitHubアカウントを持っている
- Fly.ioアカウントを持っている（`flyctl` インストール済み）

---

## セットアップ手順

### 1. リポジトリのクローン

```bash
git clone https://github.com/{username}/kakemieru.git
cd kakemieru
```

### 2. developブランチの作成

```bash
git switch -c develop
git push origin develop
```

GitHubの「Default branch」は `main` のままにする。

### 3. 環境変数ファイルの準備

```bash
cp .env.example .env
# .env を編集して POSTGRES_PASSWORD を設定
```

### 4. Dockerイメージのビルド

```bash
docker compose build
```

詳細は [ADR-0003: Docker構成](decisions/0003-docker-setup.md) を参照。

### 5. Railsプロジェクトの初期化

```bash
# Gemをインストール
docker compose run web bundle install

# Railsアプリを生成（既存ファイルを上書き）
docker compose run web bundle exec rails new . --force --database=postgresql --skip-test

# 生成後に再ビルド（Gemfile.lockが更新されるため）
docker compose build
```

> **Note**: `rails new` 実行後、Dockerfileはデフォルトの本番向けものに上書きされる。
> その後 `docker compose build` で development ステージを含む状態に再ビルドする。

### 6. データベースの接続確認

```bash
docker compose up -d db
docker compose run web bundle exec rails db:create
docker compose run web bundle exec rails db:migrate
```

### 7. ローカル動作確認

```bash
docker compose up
# http://localhost:3000 にアクセス
```

---

### 8. Fly.ioアプリの作成

```bash
flyctl auth login
flyctl launch  # fly.toml が生成される
```

- Region: `nrt`（東京）を選択
- PostgreSQL: 作成する（Fly Postgres）
- Auto-deploy: No

### 9. Fly.ioの環境変数設定

```bash
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
# DATABASE_URL は Fly Postgres 作成時に自動設定される
```

詳細は [ADR-0004: 環境変数管理](decisions/0004-env-management.md) を参照。

### 10. FLY_API_TOKENの取得

```bash
fly tokens create deploy
# 出力されたトークンを控える
```

---

### 11. GitHub Secretsの設定

GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」で以下を登録：

| Secret名 | 値 |
|---|---|
| `FLY_API_TOKEN` | `fly tokens create deploy` で取得したトークン |
| `RAILS_MASTER_KEY` | `config/master.key` の内容 |

### 12. GitHub Actionsの設定

`.github/workflows/` に以下のワークフローを配置する（詳細は [ADR-0005: CI/CD構成](decisions/0005-cicd-pipeline.md) を参照）：

| ファイル名 | トリガー | 内容 |
|---|---|---|
| `ci.yml` | PR作成・更新 | テスト・Lint |
| `deploy.yml` | タグpush（`v*`） | Fly.ioへデプロイ |

### 13. ブランチ保護の設定

GitHubの「Settings」→「Branches」で設定：

| ブランチ | 設定 |
|---|---|
| `main` | PR必須、direct push禁止 |
| `develop` | PR必須、direct push禁止 |

---

### 14. 動作確認（初回デプロイ）

```bash
git switch main
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actionsのワークフローが実行され、Fly.ioへデプロイされることを確認する。

---

## 完了チェックリスト

完了状況は [TODO.md](../TODO.md) の「初期セットアップ完了チェックリスト」で管理する。
