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

## インストールパッケージ一覧

### base ステージ（ランタイム依存）

全ステージ・本番イメージに含まれる。

| パッケージ | 用途 | なぜ必要か |
|---|---|---|
| `curl` | HTTP リクエスト | ヘルスチェック・外部ファイル取得 |
| `libjemalloc2` | メモリアロケータ | Ruby のメモリ断片化を防ぎパフォーマンス向上 |
| `libvips` | 画像処理ライブラリ | Active Storage の画像変換（Rails 7+ のデフォルト） |
| `postgresql-client` | PostgreSQL クライアント | `pg_isready`（DB 起動待ち）、`pg_dump`（バックアップ）等 |

### build_tools ステージ（ビルド時のみ）

Gem のコンパイルに使用。**本番イメージには含まれない**。

| パッケージ | 用途 | なぜ必要か |
|---|---|---|
| `build-essential` | C コンパイラ一式（gcc 等） | ネイティブ拡張を持つ Gem（pg 等）のコンパイル |
| `git` | Git | Gemfile で `git:` 指定の Gem を取得する場合に必要 |
| `libpq-dev` | PostgreSQL 開発ヘッダー | `pg` gem のコンパイルに必要（接続ライブラリ） |
| `libyaml-dev` | YAML ライブラリ開発ヘッダー | Ruby 3.4 以降で `psych` gem のビルドに必要 |
| `pkg-config` | ライブラリ設定取得ツール | コンパイル時にライブラリのパスを解決 |

### Gem（Ruby ライブラリ）

| Gem | 用途 |
|---|---|
| `pg` | PostgreSQL アダプター（`libpq-dev` でコンパイル） |
| `bootsnap` | 起動高速化（Ruby ファイルをキャッシュ） |
| `thruster` | Rails 8 内蔵プロキシ（圧縮・キャッシュ・HTTP/2） |

---

## Dockerfile の読み方

### マルチステージビルドとは

1 つの Dockerfile に `FROM ... AS ステージ名` で複数のステージを定義する書き方。
従来はローカル用・本番用でファイルを分けていたが、1 ファイルにまとめられる。

```
# 従来（ファイル分割）     # マルチステージ（1ファイル）
Dockerfile.dev            FROM ruby AS base
Dockerfile                FROM base AS build_tools
                          FROM build_tools AS development  ← ローカル
                          FROM build_tools AS build
                          FROM base AS production          ← 本番
```

### このプロジェクトのステージ構成

```
base（ランタイムのみ）
  └── build_tools（コンパイラ追加）
        ├── development   ← ローカル開発用
        └── build         ← 本番ビルド用
              ↓ 成果物だけコピー
        production        ← 本番デプロイ用（build_tools を含まない）
```

#### base ステージ
```dockerfile
FROM ruby:3.4.9-slim AS base
```
- 全ステージが継承する共通ベース
- `curl`, `libvips`, `postgresql-client` などのランタイム依存のみ
- `-slim` で最小限のイメージサイズ

#### build_tools ステージ
```dockerfile
FROM base AS build_tools
RUN apt-get install build-essential git libpq-dev ...
```
- `build-essential`（gcc 等）を追加
- Gem のコンパイルに必要
- **最終的な本番イメージには含まれない**

#### development ステージ
```dockerfile
FROM build_tools AS development
ENV RAILS_ENV="development"
RUN bundle install   # dev/test Gem を含む全 Gem をインストール
```
- `docker-compose.override.yml` の `target: development` で使われる
- ソースコードは COPY しない（ボリュームマウントで渡す）

#### build ステージ
```dockerfile
FROM build_tools AS build
ENV BUNDLE_WITHOUT="development test"
RUN bundle install        # 本番 Gem のみ
RUN bundle exec bootsnap precompile ...
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
```
- 本番用 Gem のインストールとアセットのプリコンパイル
- `bootsnap` で起動を高速化
- `SECRET_KEY_BASE_DUMMY=1` はアセットコンパイル時に本物の秘密鍵が不要なため

#### production ステージ
```dockerfile
FROM base AS production   # build_tools ではなく base を継承
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails
RUN useradd rails ... && chown -R rails:rails ...
USER 1000:1000
CMD ["./bin/thrust", "./bin/rails", "server"]
```
- `base` から継承することでコンパイラが入らない（イメージが軽い）
- `--from=build` で build ステージの成果物だけを取り込む
- 非 root ユーザー `rails` で実行（セキュリティ）
- `Thruster` 経由で起動: Rails 8 内蔵の圧縮・キャッシュ・HTTP/2 対応プロキシ

### イメージサイズの違い

| ステージ | サイズ目安 | 理由 |
|---|---|---|
| development | ~800MB | コンパイラ・全 Gem 含む |
| production | ~200MB | ランタイムと本番 Gem のみ |

### ステージの指定方法

```bash
# ビルド時に --target で指定
docker build --target development .
docker build --target production .

# docker-compose では build.target で指定
# docker-compose.override.yml → target: development
# docker-compose.yml          → target: production
```

### 各環境でどのステージが使われるか

| 環境 | ステージ | 方法 |
|---|---|---|
| ローカル開発 | development | `docker compose up`（override.yml が自動マージ） |
| CI（テスト） | production or development | `docker compose up -d db` で DB のみ起動 |
| 本番（Fly.io） | production | `fly deploy`（Dockerfile 直接） |

---

## 結果

[docs/INITIAL_SETUP.md](../INITIAL_SETUP.md) に構築手順として反映済み。
