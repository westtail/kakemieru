# CI/CD 解説ドキュメント

---

## CI（継続的インテグレーション）`.github/workflows/ci.yml`

コードをプッシュ・PR作成したとき自動でコード品質をチェックする仕組み。

### トリガー設定

```yaml
on:
  pull_request:       # PRを作成・更新したとき
  push:
    branches: [ main ] # mainブランチにpushしたとき
```

---

### job: scan_ruby（Rubyセキュリティスキャン）

```yaml
scan_ruby:
  runs-on: ubuntu-latest  # GitHub が用意する Ubuntu の仮想マシン上で実行
```

```yaml
- uses: actions/checkout@v4  # リポジトリのコードを仮想マシンにダウンロード
```

```yaml
- uses: ruby/setup-ruby@v1   # Ruby をセットアップするアクション（公式提供）
  with:
    ruby-version: .ruby-version  # .ruby-version ファイルに書かれたバージョンを使う
    bundler-cache: true          # Gemfile.lock をキャッシュして次回以降の速度を上げる
```

```yaml
- run: bin/brakeman --no-pager
  # Brakeman: Railsアプリのセキュリティ脆弱性を静的解析するツール
  # SQLインジェクション、XSSなどの問題を検出
  # --no-pager: ページャー（lessコマンド等）を使わずそのまま出力
```

---

### job: scan_js（JavaScriptセキュリティスキャン）

```yaml
- run: bin/importmap audit
  # importmap を使っているJSパッケージの既知の脆弱性をチェック
  # npm audit に相当する処理
```

---

### job: lint（コードスタイルチェック）

```yaml
- run: bin/rubocop -f github
  # RuboCop: Rubyのコードスタイルをチェックするツール
  # インデント・命名規則・構文などを自動チェック
  # -f github: GitHub Actions のUI上でエラー箇所を見やすく表示する出力形式
```

---

### job: test（テスト実行）

```yaml
services:
  postgres:                    # テスト用のPostgreSQLをDockerコンテナとして起動
    image: postgres            # Docker Hub の公式postgresイメージを使用
    env:
      POSTGRES_USER: postgres      # DBのユーザー名
      POSTGRES_PASSWORD: password  # DBのパスワード（CI用なのでハードコードでOK）
    ports:
      - 5432:5432              # ホスト:コンテナ のポートマッピング（標準ポート）
    options: >-                # >- は複数行を1行につなげるYAML記法
      --health-cmd pg_isready  # PostgreSQLが起動完了したか確認するコマンド
      --health-interval 10s    # 10秒ごとにヘルスチェック
      --health-timeout 5s      # 5秒以内に応答がなければ失敗とみなす
      --health-retries 5       # 5回失敗したらコンテナをunhealthyとする
      # → PostgreSQLが完全に起動するまで次のstepを待たせる仕組み
```

```yaml
env:
  RAILS_ENV: test   # Railsをテスト環境モードで動かす
  DATABASE_URL: postgres://postgres:password@localhost:5432/kakemieru_test
  # Railsがテスト用DBに接続するための接続文字列
  # 形式: postgres://ユーザー:パスワード@ホスト:ポート/DB名
```

```yaml
run: |
  bin/rails db:create db:schema:load  # テスト用DBを作成してスキーマを流し込む
  bin/rails test                      # minitest でテストを全件実行
```

---

## CD（継続的デプロイ）`.github/workflows/fly-deploy.yml`

mainブランチへのpushをトリガーに、Fly.io へ自動デプロイする仕組み。

```yaml
on:
  push:
    branches:
      - main  # mainへのpushのみ（PRはデプロイしない）
```

```yaml
concurrency: deploy-group
# 同時に複数のデプロイが走らないようにする
# 例: 連続してpushしたとき、前のデプロイが終わるまで次を待たせる
```

```yaml
- uses: superfly/flyctl-actions/setup-flyctl@v1
  # flyctl（Fly.ioのCLIツール）をCIの仮想マシンにインストール
```

```yaml
- run: flyctl deploy --remote-only
  env:
    FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
  # flyctl deploy: Fly.io へデプロイを実行
  # --remote-only: ビルドをローカルではなくFly.ioのリモートビルダーで行う
  #   → CI上でDockerをインストールしなくて済む・ビルドが速い
  # FLY_API_TOKEN: GitHub の Secrets に登録した認証トークン
  #   ${{ secrets.XXX }} で安全に参照できる（ログには表示されない）
```

---

## 全体の流れ

```
PRを作成
  └─ CI が自動実行
       ├─ scan_ruby  （Rubyセキュリティ）
       ├─ scan_js    （JSセキュリティ）
       ├─ lint       （コードスタイル）
       └─ test       （テスト）
            ↓ 全部グリーンになったらマージ可能

mainにマージ
  └─ CD が自動実行
       └─ deploy → Fly.io に本番デプロイ
```
