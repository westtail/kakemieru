# Git ブランチ戦略

最終更新: 2026-03-13

---

## ブランチ命名規則

```
{type}/{issue番号}-{説明}
```

### 例

```
feat/42-user-authentication
fix/17-login-redirect-bug
chore/3-docker-setup
refactor/28-extract-auth-service
docs/5-api-reference
test/33-add-user-model-specs
perf/61-optimize-n-plus-one
ci/8-github-actions-setup
```

### タイプ一覧

| タイプ | 用途 |
|---|---|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `refactor` | リファクタリング（機能変更なし） |
| `docs` | ドキュメントのみ |
| `test` | テストのみ |
| `chore` | 設定・環境・依存関係など |
| `perf` | パフォーマンス改善 |
| `ci` | CI/CD設定 |

### ルール

- 小文字 + ハイフン区切り
- Issue番号は必須（Issueなしの作業は先にIssueを作る）
- 説明は英語、動詞または名詞で簡潔に
- 目安40文字以内

---

## ブランチ戦略

### 主要ブランチ

| ブランチ | 役割 |
|---|---|
| `main` | 本番リリース済みコード（手動デプロイ） |
| `develop` | 開発統合ブランチ（PR先） |

### 作業フロー

```
main
 └── develop ← 通常のPR先
       └── feat/42-user-authentication
       └── fix/17-login-redirect-bug
```

リリース時: `develop` → `main` へPR、タグpush（`v*`）でFly.ioへ自動デプロイ

### PR ルール

- 1ブランチ = 1Issue
- PRタイトルは `{type}: {説明} (#{issue番号})` 形式
- 通常は `develop` へ、リリース時のみ `main` へ
- セルフレビュー後にマージ

### ブランチ保護

- `main`: direct push禁止、PR必須
- `develop`: direct push禁止、PR必須

---

## TODO（レビュー用）

- [x] `develop` ブランチを設ける → **採用**
- [x] PRのsquash mergeにするか、merge commitにするか → **merge commit採用**（作業ログ・調査・意図を残すため）
- [x] デプロイ先選定 → **Fly.io採用**（ADR-0006参照）。タグpushでGitHub Actions経由で自動デプロイ
- [x] `develop` → `main` PRのタイミング → **機能単位採用**（調査の切り分けしやすさ、未完成機能はdevelopで保持）
- [x] コミットメッセージのlint → **不採用**（AIとのコミットメッセージ作成コマンドで代替）

git flow 
https://nvie.com/posts/a-successful-git-branching-model/