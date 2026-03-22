# ADR-0003: Docker構成

- 日付: 2026-03-21
- ステータス: 決定済み

---

## コンテキスト

ローカル開発環境と本番環境の構成方法を決定する必要があった。
PROJECT_OVERVIEW.mdでDocker化は既に決定済みだが、具体的な構成を定義する。

---

## 決定事項

### 1. 使用するDockerイメージ

**決定**: Ruby公式イメージをベースにする

```
web:  ruby:3.x-slim
db:   postgres:16-alpine
```

**理由**:
- slim/alpineで軽量化
- 公式イメージで信頼性が高い

### 2. docker-composeの構成

**決定**: `web`（Rails）と `db`（PostgreSQL）の2サービス構成

```yaml
services:
  web:   # Railsアプリ
  db:    # PostgreSQL
```

**理由**:
- 最小構成でシンプルに保つ
- 将来Redisなどが必要になった時点で追加する

### 3. ローカルと本番の環境分離

**決定**: `docker-compose.yml`（共通）+ `docker-compose.override.yml`（ローカル専用）

| ファイル | 用途 |
|---|---|
| `docker-compose.yml` | 本番・CI共通の基本定義 |
| `docker-compose.override.yml` | ローカル専用（ボリュームマウント、ポート公開等） |

**理由**:
- ローカル特有の設定を本番に混入させない
- `docker-compose.override.yml` はdocker composeが自動で読み込む

### 4. Railsのボリュームマウント

**決定**: ローカル開発時はソースコードをマウントする

**理由**:
- コード変更を即時反映（rebuild不要）
- 開発効率の向上

### 5. Fly.ioへのデプロイ形式

**決定**: DockerfileをFly.ioに読み込ませてデプロイ（`flyctl deploy`）

**理由**:
- ローカルと同じDockerイメージを本番で動かせる
- ベンダーロックインを避けられる（ADR-0006参照）
- Fly.ioはDockerネイティブで設定がシンプル

---

## 結果

[docs/INITIAL_SETUP.md](../INITIAL_SETUP.md) に構築手順として反映済み。
