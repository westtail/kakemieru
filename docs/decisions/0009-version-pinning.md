# ADR-0009: バージョン固定戦略

- 日付: 2026-03-22
- ステータス: 決定済み

---

## コンテキスト

依存関係のバージョン管理方針を決定する必要があった。
バージョンを固定しないと、再現性のない環境が生まれ、開発・本番間の差異や予期しない破壊的変更のリスクがある。
一方で固定範囲を広げすぎると、管理コストが上がり逆にビルド失敗のリスクが出る場合もある。

---

## 決定事項

### 1. Ruby バージョン

**決定**: `3.4.9` に固定する（Dockerfile の `ARG RUBY_VERSION=3.4.9`）

**選定理由**:

| バージョン | EOL | 備考 |
|---|---|---|
| 3.3.x | 2027-03 | 旧来の実績あり |
| **3.4.9** | 2028-03 | 安定実績・EOL 1年長い ← 採用 |
| 4.0.x | 2029-03 | リリース3ヶ月、Gem互換性リスクあり |

- EOLが2028年まであり保守期間が十分
- Rails 8.0との互換性が実証済み
- Ruby 4.0はリリースから日が浅くGemの一部が未対応の可能性がある

---

### 2. Rails バージョン

**決定**: `= 8.0.4` に固定する（Gemfile）

```ruby
gem "rails", "= 8.0.4"
```

- `~>` ではなく `=` を使い、マイナー・パッチ更新も意図的に管理する
- アップグレードはCHANGELOGを確認した上で手動で実施する

---

### 3. Gem のバージョン

**決定**: `Gemfile.lock` をコミットしてバージョンを固定する

- `rails new` 後に生成される `Gemfile.lock` をGit管理に含める
- 主要Gemは `Gemfile` で `= x.y.z` 形式で明示的に固定する
- 依存Gemは `Gemfile.lock` で間接的に固定される

---

### 4. Docker ベースイメージ

**決定**: タグ指定（`ruby:3.4.9-slim`）で固定する。ダイジェスト固定はしない

```dockerfile
ARG RUBY_VERSION=3.4.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
```

- タグ固定で十分な再現性が得られる
- ダイジェスト（SHA256）固定はセキュリティパッチを手動で追跡する必要があり、個人開発では管理コストが高い

---

### 5. apt パッケージ（Dockerfile 内）

**決定**: バージョン固定しない

```dockerfile
# NG: apt-get install postgresql-client=15.x-y ...
# OK: apt-get install postgresql-client
apt-get install --no-install-recommends -y \
  curl \
  libjemalloc2 \
  postgresql-client
```

**理由**:

- apt パッケージのバージョンは Debian リリースに紐づいており、`ruby:3.4.9-slim` ベースイメージ自体がそのスナップショットを保証している
- バージョンを明示的に固定すると、ベースイメージ更新時にリポジトリから当該バージョンが消えてビルドが壊れるリスクがある
- ベースイメージのタグを固定することで、apt パッケージのバージョンも間接的に安定する

---

## バージョンアップグレード方針

| 対象 | タイミング | 方法 |
|---|---|---|
| Ruby | EOLの6ヶ月前 | Dockerfile の `RUBY_VERSION` を変更 |
| Rails | セキュリティパッチ時 / 四半期ごとに確認 | Gemfile の `=` バージョンを変更し `bundle update rails` |
| Gem | 四半期ごとに確認 | `bundle update` + テスト確認 |
| Docker ベースイメージ | セキュリティ勧告時 | タグ変更 |

---

## 結果

- `Dockerfile`: Ruby `3.4.9` 固定
- `Gemfile`: Rails `= 8.0.4` 固定
- `Gemfile.lock`: Gitにコミットしてバージョンをロック
- apt パッケージ: ベースイメージのタグ固定に委ねる
