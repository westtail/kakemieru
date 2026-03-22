# ADR-0004: 環境変数管理

- 日付: 2026-03-21
- ステータス: 決定済み

---

## コンテキスト

ローカル・本番・CIそれぞれの環境変数をどう管理するか決定する必要があった。
シークレットをコードに含めず、かつ開発効率を損なわない方法を選ぶ。

---

## 決定事項

### 1. ローカル環境の変数管理

**決定**: `.env` ファイルを使用する（`.gitignore` に追加）

```bash
# .env（Gitにコミットしない）
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=kakemieru_development
```

`.env.example`（ダミー値入り）をGitに含め、セットアップ手順に記載する。

**理由**:
- Dockerがデフォルトで `.env` を読み込む
- `.env.example` でどの変数が必要か分かる

### 2. Railsのシークレット管理

**決定**: Rails credentials（`config/credentials.yml.enc`）を使用する

- `config/master.key` はGitにコミットしない（`.gitignore` に追加済み）
- 本番の `RAILS_MASTER_KEY` はRenderの環境変数で設定する

**理由**:
- Railsの標準機能を使う
- `credentials.yml.enc` はGitにコミットできる（暗号化済みのため）

### 3. 本番環境の変数管理

**決定**: `fly secrets set` コマンドで設定する

| 変数名 | 内容 |
|---|---|
| `DATABASE_URL` | Fly PostgreSQL接続URL |
| `RAILS_MASTER_KEY` | `config/master.key` の内容 |
| `RAILS_ENV` | `production` |

```bash
fly secrets set RAILS_MASTER_KEY=xxxx
fly secrets set DATABASE_URL=xxxx
```

**理由**:
- Fly.ioがシークレットを暗号化して安全に管理
- コードに含めることなく本番へ渡せる

### 4. CI環境の変数管理

**決定**: GitHub Secretsを使用する

| Secret名 | 用途 |
|---|---|
| `FLY_API_TOKEN` | Fly.ioへのデプロイ認証 |
| `RAILS_MASTER_KEY` | CI上でのテスト実行用 |

```bash
fly tokens create deploy  # FLY_API_TOKEN を取得
```

**理由**:
- GitHub Actionsとの統合がシンプル
- シークレットがログに出力されない

---

## 禁止事項

- APIキー・パスワード・トークンをコードにハードコードしない
- `.env` や `master.key` をGitにコミットしない
- ログにシークレットを出力しない

---

## 結果

[docs/INITIAL_SETUP.md](../INITIAL_SETUP.md) にセットアップ手順として反映済み。
