# 開発フロー

最終更新: 2026-03-21

---

## 前提

このドキュメントは、開発環境・CI/CD・デプロイ基盤が整った状態での通常開発フローを定義する。
初期セットアップは [INITIAL_SETUP.md](INITIAL_SETUP.md) を参照。

---

## フロー概要

```
Issue作成
  ↓
ADR作成（必要な場合）
  ↓
ブランチ作成（develop から）
  ↓
実装（TDD）
  ↓
コミット
  ↓
PR作成 → develop へマージ
  ↓
develop → main へPR（機能単位）
  ↓
リリースタグ作成 → 自動デプロイ
```

---

## 各ステップの詳細

### 1. Issue作成

- GitHubでIssueを作成する
- タイトル: 何をするかを1行で
- 本文: 背景・目的・完了条件を記載
- ラベル・Projectを設定する

### 2. ADR作成（任意）

以下に該当する場合はADRを先に書く：

- 技術的な方針を決定する
- 複数の選択肢を検討した
- 後で「なぜこうしたか」を残したい

ADRは `docs/decisions/XXXX-{title}.md` に保存。
フォーマットは既存のADRに準拠。

### 3. ブランチ作成

```bash
git switch develop
git pull origin develop
git switch -c {type}/{issue番号}-{説明}
```

命名規則は [GIT_STRATEGY.md](GIT_STRATEGY.md) を参照。

### 4. 実装（TDD）

1. **RED**: テストを先に書く → 失敗することを確認
2. **GREEN**: テストが通る最小限の実装をする
3. **REFACTOR**: コードを整理する（テストは通ったまま）

カバレッジ目標: 80%以上

### 5. コミット

```bash
git add {ファイル}
git commit -m "{type}: {説明}"
```

コミットタイプは [GIT_STRATEGY.md](GIT_STRATEGY.md) を参照。
wipコミットは許容。小さい単位でこまめに記録する。

### 6. PR作成 → developへマージ

```bash
git push origin {ブランチ名}
```

- GitHubでPRを作成（base: `develop`）
- PRタイトル: `{type}: {説明} (#{issue番号})`
- セルフレビューを行う
- CIが通ったことを確認してマージ

### 7. develop → main へPR（機能単位）

1機能が完成したら `develop` → `main` へPRを作成する。

- PRタイトル: `release: {機能名}`
- 動作確認済みであることを確認
- マージ後にリリースタグを作成する

### 8. リリースタグ作成 → 自動デプロイ

```bash
git switch main
git pull origin main
git tag v{major}.{minor}.{patch}
git push origin v{major}.{minor}.{patch}
```

タグpushをトリガーにGitHub ActionsがFly.ioへ自動デプロイする。
バージョニングはSemVerに準拠:

| 変更の種類 | 上げる桁 | 例 |
|---|---|---|
| 後方互換のバグ修正 | patch | v1.0.0 → v1.0.1 |
| 後方互換の新機能 | minor | v1.0.0 → v1.1.0 |
| 破壊的変更 | major | v1.0.0 → v2.0.0 |

---

## CIで自動実行されること

| タイミング | 実行内容 |
|---|---|
| PR作成・更新時 | テスト実行、Lintチェック |
| developマージ時 | テスト実行 |
| タグpush時 | Fly.ioへ自動デプロイ |

---

## 工数記録

各Issueにクローズ時に記録する：

```
見積もり: X時間
実際: X時間
学び: （任意）
```
