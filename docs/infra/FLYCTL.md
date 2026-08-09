# flyctl ガイド

最終更新: 2026-03-23

---

## flyctl とは

Fly.io の公式 CLI ツール。アプリのデプロイ・管理・監視をコマンドラインから行う。
`fly` と `flyctl` はどちらでも動く（エイリアス）。

---

## インストール

### Linux / WSL

```bash
curl -L https://fly.io/install.sh | sh
```

インストール後、シェルの設定ファイルに PATH を追加：

```bash
# ~/.bashrc または ~/.zshrc に追記
export FLYCTL_INSTALL="/home/$USER/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"
```

反映：

```bash
source ~/.bashrc  # または source ~/.zshrc
```

確認：

```bash
fly version
```

### macOS

```bash
brew install flyctl
```

### アップデート

```bash
fly version upgrade
```

---

## 初期設定

```bash
# ログイン（ブラウザが開く）
fly auth login

# ログイン確認
fly auth whoami
```

---

## よく使うコマンド

### アプリ管理

```bash
fly launch              # アプリ作成・fly.toml 生成
fly deploy              # デプロイ（Dockerfile を読み込む）
fly status              # アプリの稼働状態確認
fly apps list           # アプリ一覧
fly open                # ブラウザでアプリを開く
```

### ログ・監視

```bash
fly logs                # ログをリアルタイム表示
fly logs -i <instance>  # 特定インスタンスのログ
fly status              # デプロイ状態・マシン状態
fly releases            # リリース履歴
fly metrics             # CPU・メモリ使用率
```

### シークレット管理

```bash
fly secrets list                              # シークレット一覧
fly secrets set KEY=value                     # シークレット設定
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
fly secrets unset KEY                         # シークレット削除
```

### SSH・コンソール

```bash
fly ssh console                        # インスタンスに SSH 接続
fly ssh console -C "rails console"     # Rails コンソールを開く
fly ssh console -C "rails db:migrate"  # マイグレーション実行
```

### スケール・設定変更

```bash
fly scale memory 512    # メモリを 512MB に変更
fly scale count 1       # インスタンス数を 1 に変更
fly scale show          # 現在のスケール設定確認
```

---

## Fly Postgres（自己管理型）

> **注意**: Fly.io には「Fly Postgres（自己管理）」と「Managed PostgreSQL（MPG）」の 2 種類がある。
> `flyctl launch` で作成するのは自己管理型。サポート対象外だが安価（$2〜/月）。

### 作成

```bash
fly postgres create \
  --name kakemieru-db \
  --region nrt \
  --vm-size shared-cpu-1x \
  --volume-size 10
```

### アプリに接続

```bash
fly postgres attach --app kakemieru kakemieru-db
# DATABASE_URL シークレットが自動設定される
```

### DB 接続確認

```bash
fly postgres connect -a kakemieru-db
```

### バックアップ

```bash
# 日次スナップショットは自動取得
fly postgres list-snapshots -a kakemieru-db

# スナップショットから復元
fly postgres restore -a kakemieru-db --snapshot-id <id>
```

---

## fly.toml の主要設定

`fly launch` で自動生成される。主なカスタマイズ箇所：

```toml
app = "kakemieru"
primary_region = "nrt"  # 東京

[build]
  # Dockerfile を使用（デフォルト）

[env]
  RAILS_ENV = "production"
  SOLID_QUEUE_IN_PUMA = "true"  # Solid Queue を Puma 内で動かす

[http_service]
  internal_port = 80  # Thruster がポート 80 で待ち受け
  force_https = true

[[vm]]
  memory = "256mb"   # 256MB で様子見 → 重ければ 512mb に変更
  cpu_kind = "shared"
  cpus = 1
```

---

## よくあるトラブルと対処

### デプロイが失敗する

```bash
fly logs  # まずログを確認
```

**よくある原因：**

| エラー | 対処 |
|---|---|
| `SECRET_KEY_BASE` が未設定 | `fly secrets set RAILS_MASTER_KEY=...` |
| DB 接続エラー | `fly postgres attach` で接続確認 |
| マイグレーション未実行 | `fly ssh console -C "rails db:migrate"` |
| メモリ不足（OOM） | `fly scale memory 512` |

### Rails コンソールに接続できない

```bash
fly ssh console -C "/rails/bin/rails console"
```

パスが通らない場合：

```bash
fly ssh console
cd /rails
bin/rails console
```

### マイグレーション失敗

```bash
# ログ確認
fly logs

# 手動実行
fly ssh console -C "cd /rails && bin/rails db:migrate"

# ロールバック
fly ssh console -C "cd /rails && bin/rails db:rollback"
```

### メモリ使用率が高い

```bash
# 現在の使用率確認
fly metrics

# メモリ増量
fly scale memory 512
```

### デプロイは成功したが画面が表示されない

```bash
# ヘルスチェック確認
fly status

# ログ確認
fly logs

# よくある原因
# - ENTRYPOINT の db:prepare が失敗している
# - アセットのプリコンパイルが失敗している
```

---

## GitHub Actions での CD 設定

```yaml
# .github/workflows/deploy.yml
- name: Deploy to Fly.io
  uses: superfly/flyctl-actions/setup-flyctl@master
- run: fly deploy --remote-only
  env:
    FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

**必要な GitHub Secrets：**

| Secret 名 | 取得方法 |
|---|---|
| `FLY_API_TOKEN` | `fly tokens create deploy` |
| `RAILS_MASTER_KEY` | `cat config/master.key` |

---

## 参考

- [Fly.io 公式ドキュメント](https://fly.io/docs/)
- [flyctl コマンドリファレンス](https://fly.io/docs/flyctl/)
- [Fly Postgres ドキュメント](https://fly.io/docs/postgres/)
- [ADR-0006: ホスティング戦略](decisions/0006-hosting-strategy.md)
