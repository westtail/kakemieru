# ADR-0008: シークレット管理・セキュリティ方針

- 日付: 2026-03-22
- ステータス: 決定済み

---

## コンテキスト

シークレット（APIキー・パスワード・暗号化キー）の漏洩は、修正が極めて困難で影響範囲が広い。
一度 Git にコミットされた情報は、たとえ削除しても履歴に永久に残る。
このドキュメントでは「何がなぜ危険か」「どう防ぐか」を具体例とともに整理する。

---

## シークレットの管理場所

| 種類 | ローカル | 本番 | Git |
|---|---|---|---|
| DB パスワード | `.env` | `fly secrets set` | **NG** |
| Stripe / 外部 API キー | `credentials.yml.enc` | `RAILS_MASTER_KEY` を設定すれば復号 | OK（暗号化済） |
| Rails 復号鍵（master.key） | `config/master.key` ファイル | `fly secrets set RAILS_MASTER_KEY` | **絶対 NG** |
| CI 認証（FLY_API_TOKEN等） | — | GitHub Secrets | **NG** |

---

## Rails credentials の仕組み

### 概念

```
credentials.yml.enc  ← 暗号化済みファイル（Git にコミット OK）
      ↑ 暗号化
master.key           ← 復号鍵（Git にコミット NG）
```

`master.key` さえ守れば、`credentials.yml.enc` はリポジトリに含めてよい。
逆に `master.key` が漏れると、`credentials.yml.enc` の全内容が復号される。

### 書き込み

```bash
rails credentials:edit
# EDITOR が開く。保存すると credentials.yml.enc に暗号化して保存される
```

```yaml
# 編集内容の例（平文で書く）
aws:
  access_key_id: AKIAIOSFODNN7EXAMPLE
  secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

stripe:
  secret_key: sk_live_xxxxxxxxxxxx

secret_key_base: a1b2c3d4e5f6...  # Rails が自動生成
```

### 読み出し

```ruby
# 階層アクセス
Rails.application.credentials.dig(:aws, :access_key_id)
Rails.application.credentials.aws[:secret_access_key]
```

### DB 接続情報は credentials に入れない

DB URL はプラットフォームが自動注入する慣例があるため、環境変数で渡す。

```yaml
# config/database.yml
production:
  url: <%= ENV["DATABASE_URL"] %>
```

---

## 致命的なミスとその対策

### ❌ ミス1: `master.key` を Git にコミットする（致命度: 最高）

**なぜ致命的か**:
`master.key` が漏れると `credentials.yml.enc` の全内容が復号できる。
Git に一度コミットされると、ブランチを削除しても履歴に残り続ける。
GitHub の public リポジトリなら即座に全世界に公開される。

**防ぎ方**:
```bash
# .gitignore に記載済みであることを確認
git check-ignore -v config/master.key
# → .gitignore:18:config/master.key  config/master.key  と出れば OK

# ステージングに含まれていないか確認してからコミット
git status  # master.key が表示されていないことを確認
```

**やってしまった場合**:
1. 即座に `master.key` をローテーション（`rails credentials:edit` で新しい鍵を生成）
2. credentials に入っていた全シークレット（APIキー等）を再発行
3. git history からの削除を試みる（`git filter-repo` 等）が、漏洩したとみなして対処する

---

### ❌ ミス2: `.env` を Git にコミットする（致命度: 高）

**なぜ致命的か**:
`.env` には DB パスワードが入っており、直接 DB に接続できてしまう。
`git add .` の一発で巻き込まれやすい。

**防ぎ方**:
```bash
# .gitignore を先に作ってから .env を作る（今回はこの順序で作成済み）
# ステージング前に確認
git check-ignore -v .env
# → .gitignore:2:.env  .env  と出れば OK
```

**やってしまった場合**:
```bash
git rm --cached .env   # Git の追跡から外す
# DB パスワードを即座にローテーション
# git history から削除: git filter-repo --path .env --invert-paths
```

---

### ❌ ミス3: `master.key` がコンテナイメージに含まれる（致命度: 高）

**なぜ危険か**:
Dockerfile の `COPY . .` で `master.key` が含まれてしまう。
イメージを Docker Hub 等に push すると漏洩する。
イメージの中間レイヤーにも残るため、単純な削除では消えない。

**防ぎ方（`.dockerignore` で除外）**:
```
# .dockerignore
config/master.key
config/credentials/*.key
.env
```

**本番での渡し方**:
```bash
# ファイルではなく環境変数で渡す
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
```

---

### ❌ ミス4: ログにシークレットが出力される（致命度: 中〜高）

**なぜ危険か**:
アプリのログは Fly.io の管理画面、監視ツール、開発者全員が見られる。
デバッグ中に誤って API キーをログに出すと、ログを見た全員に漏洩する。

**防ぎ方**:
```ruby
# config/initializers/filter_parameter_logging.rb
# Rails はこのキーワードを含むパラメータをログでマスクする
Rails.application.config.filter_parameters += [
  :password, :secret, :token, :api_key, :_key, :passphrase, :credential
]
# ログ出力: [FILTERED] と表示される
```

```ruby
# NG: ログに直接出さない
Rails.logger.info "key: #{api_key}"

# OK: 値を出す必要があるならマスクする
Rails.logger.info "key: #{api_key.first(4)}****"
```

---

### ❌ ミス5: `RAILS_MASTER_KEY` を CI のログに出力する（致命度: 高）

**なぜ危険か**:
GitHub Actions のログはデフォルトでリポジトリの collaborator 全員が見られる。
Public リポジトリでは全世界に公開される。

**防ぎ方**:
```yaml
# GitHub Actions: シークレットは env 経由で渡す
env:
  RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}

# NG: run の中で echo しない
- run: echo $RAILS_MASTER_KEY   # ログに出る
```

---

### ❌ ミス6: シークレットをコードにハードコードする（致命度: 最高）

**なぜ危険か**:
コードにハードコードすると、リポジトリを見た人全員に漏洩する。
特に OSS・public リポジトリでは即座に全世界公開。

```ruby
# NG
STRIPE_KEY = "sk_live_xxxxxxxxxxxx"
s3_client = Aws::S3::Client.new(access_key_id: "AKIA...")

# OK
STRIPE_KEY = Rails.application.credentials.stripe[:secret_key]
s3_client = Aws::S3::Client.new(
  access_key_id: Rails.application.credentials.dig(:aws, :access_key_id)
)
```

---

## 漏洩が起きた場合の対応手順

1. **即座に停止**: 漏洩したシークレットを使ったサービスへのアクセスを遮断
2. **ローテーション**: 漏洩したキー・パスワードを即座に無効化・再発行
3. **影響範囲の確認**: 漏洩したキーで何が行われたかサービスのアクセスログを確認
4. **git history の削除**: `git filter-repo` で試みる（ただし漏洩したとみなして対処）
5. **再発防止**: なぜ防げなかったか原因を特定し、checklist を更新

---

## 事前チェックリスト（コミット前）

```bash
# シークレットが含まれていないか確認
git status              # .env, master.key が含まれていないか
git diff --staged       # ステージングされた内容を目視確認
```

自動化（推奨）:
- `git-secrets`（AWS 製）: AWS キーのパターンを自動検出
- `gitleaks`: 汎用シークレット検出ツール
- GitHub の Secret scanning: public リポジトリは自動でスキャン済み

---

## 結果

- [.gitignore](../../.gitignore): `.env`, `master.key`, `credentials/*.key` を除外済み
- [.dockerignore](../../.dockerignore): 同上をコンテナイメージからも除外済み
- [.env.example](../../.env.example): ダミー値入りテンプレートを Git に含める運用
- [ADR-0004](0004-env-management.md): 各環境での変数管理方針
