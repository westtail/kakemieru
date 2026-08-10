# 初期セットアップ手順（本番インフラ）

ローカル開発環境の起動は [README.md](../../README.md) を参照。
このドキュメントは Fly.io・GitHub Actions・ブランチ保護など本番インフラの初回設定手順を定義する。

---

## 前提条件

- Fly.io アカウントを持っている（`flyctl` インストール済み）
- GitHub リポジトリが作成済み

---

## 手順

### 1. Fly.io アプリの作成

```bash
flyctl auth login
flyctl launch  # fly.toml が生成される
```

- Region: `nrt`（東京）を選択
- PostgreSQL: 作成する（Fly Postgres）
- Auto-deploy: No

### 2. Fly.io の環境変数設定

```bash
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
# DATABASE_URL は Fly Postgres 作成時に自動設定される
```

### 3. FLY_API_TOKEN の取得

```bash
fly tokens create deploy
# 出力されたトークンを控える
```

### 4. GitHub Secrets の設定

GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」で以下を登録：

| Secret 名 | 値 |
|---|---|
| `FLY_API_TOKEN` | `fly tokens create deploy` で取得したトークン |
| `RAILS_MASTER_KEY` | `config/master.key` の内容 |

### 5. GitHub Actions の設定

`.github/workflows/` に以下のワークフローを配置：

| ファイル名 | トリガー | 内容 |
|---|---|---|
| `ci.yml` | PR 作成・更新 | テスト・Lint |
| `deploy.yml` | タグ push（`v*`） | Fly.io へデプロイ |

詳細は [CI_CD.md](CI_CD.md) を参照。

### 6. ブランチ保護の設定

GitHubの「Settings」→「Branches」で設定：

| ブランチ | 設定 |
|---|---|
| `main` | PR 必須、direct push 禁止 |
| `develop` | PR 必須、direct push 禁止 |

### 7. 初回デプロイ確認

```bash
git switch main
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions が実行され Fly.io へデプロイされることを確認する。
