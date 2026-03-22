# 初期セットアップ手順

最終更新: 2026-03-21

---

## 概要

このドキュメントは、KakeMieru の開発環境を0から構築し、本番デプロイまでを通す手順を定義する。
一度完了すれば以降は [DEVELOPMENT_FLOW.md](DEVELOPMENT_FLOW.md) に従って開発する。

---

## 前提条件

- Docker / Docker Compose がインストール済み
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

### 3. Docker環境の構築

```bash
cp .env.example .env
# .env を編集して必要な値を設定

docker compose build
```

詳細は [ADR-0003: Docker構成](decisions/0003-docker-setup.md) を参照。

### 4. Railsプロジェクトの初期化

```bash
docker compose run --rm web rails new . --force --database=postgresql --skip-test
docker compose run --rm web bundle install
```

### 5. データベースの接続確認

```bash
docker compose up -d db
docker compose run --rm web rails db:create
docker compose run --rm web rails db:migrate
```

### 6. ローカル動作確認

```bash
docker compose up
# http://localhost:3000 にアクセス
```

---

### 7. Fly.ioアプリの作成

```bash
flyctl auth login
flyctl launch  # fly.toml が生成される
```

- Region: `nrt`（東京）を選択
- PostgreSQL: 作成する（Fly Postgres）
- Auto-deploy: No

### 8. Fly.ioの環境変数設定

```bash
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
fly secrets set RAILS_ENV=production
# DATABASE_URL は Fly Postgres 作成時に自動設定される
```

詳細は [ADR-0004: 環境変数管理](decisions/0004-env-management.md) を参照。

### 9. FLY_API_TOKENの取得

```bash
fly tokens create deploy
# 出力されたトークンを控える
```

---

### 10. GitHub Secretsの設定

GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」で以下を登録：

| Secret名 | 値 |
|---|---|
| `FLY_API_TOKEN` | `fly tokens create deploy` で取得したトークン |
| `RAILS_MASTER_KEY` | `config/master.key` の内容 |

### 11. GitHub Actionsの設定

`.github/workflows/` に以下のワークフローを配置する（詳細は [ADR-0005: CI/CD構成](decisions/0005-cicd-pipeline.md) を参照）：

| ファイル名 | トリガー | 内容 |
|---|---|---|
| `ci.yml` | PR作成・更新 | テスト・Lint |
| `deploy.yml` | タグpush（`v*`） | Fly.ioへデプロイ |

### 12. ブランチ保護の設定

GitHubの「Settings」→「Branches」で設定：

| ブランチ | 設定 |
|---|---|
| `main` | PR必須、direct push禁止 |
| `develop` | PR必須、direct push禁止 |

---

### 13. 動作確認（初回デプロイ）

```bash
git switch main
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actionsのワークフローが実行され、Fly.ioへデプロイされることを確認する。

---

## 完了チェックリスト

- [ ] ローカルで `docker compose up` が起動する
- [ ] `rails db:create` が成功する
- [ ] Renderサービスが作成されている
- [ ] GitHub Secretsが設定されている
- [ ] ブランチ保護が設定されている
- [ ] タグpushでデプロイが実行される
- [ ] 本番URLでアプリが表示される
