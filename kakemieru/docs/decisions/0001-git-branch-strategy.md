# ADR-0001: Gitブランチ戦略

- 日付: 2026-03-13
- ステータス: 決定済み（一部保留）

---

## コンテキスト

Railsプロジェクト（kakemieru）のGit運用方針を決定する必要があった。
個人開発だが、業務経験を活かした規律ある運用をしたい。
デプロイ先は未定だが、本番への意図的なコントロールは必要。

---

## 決定事項

### 1. ブランチ命名規則

**決定**: `{type}/{issue番号}-{説明}` 形式を採用

```
feat/42-user-authentication
fix/17-login-redirect-bug
chore/3-docker-setup
```

**理由**: GitHubのIssueと紐付けることで作業の追跡が容易。タイプはgit-workflow.mdの既存規則（feat, fix, refactor, docs, test, chore, perf, ci）を引き継ぐ。

---

### 2. ブランチ戦略: GitHub Flow vs Git Flow

**決定**: Git Flow（developブランチあり）を採用

```
main ← develop ← feat/xxx, fix/xxx
```

**検討した選択肢**:
- GitHub Flow（main直PR）: シンプルだが本番への意図的コントロールが弱い
- Git Flow: developで統合・確認してからmainへ

**理由**:
- 業務経験でGit Flowに慣れており認知コストが低い
- 本番デプロイを意識的にコントロールしたい
- 開発中の未完成機能をdevelopに積んでおける
- 「developで動作確認 → mainにマージ → デプロイ」の習慣を個人開発でも維持

---

### 3. マージ方式: squash merge vs merge commit

**決定**: merge commitを採用

**検討した選択肢**:
- squash merge: 履歴がきれい、1PR=1コミット
- merge commit: 作業履歴がそのまま残る

**理由**:
- gitの利点は作業ログを追えること
- 問題調査・バグ追跡時にコミット単位で原因を特定できる
- revertをコミット単位で細かくできる
- AIが過去の作業ログを参照する際にも詳細な履歴が有効
- wipコミットを許容したい場面があり、squashの「きれいさ」より履歴の保持を優先

---

### 4. develop → main のタイミング

**決定**: 機能単位でリリース

**検討した選択肢**:
- 機能単位: 1機能完成ごとにdevelop→mainへPR
- スプリント単位: 一定期間（1〜2週間）分まとめてリリース

**理由**:
- 問題発生時の切り分けが明確（どの機能が原因か特定しやすい）
- revertが機能単位でできる
- デプロイ頻度が高くなるが、それはOK
- 個人開発でスプリント管理のオーバーヘッドは不要
- スプリント単位は中〜大規模チームや複数バージョン管理が必要な場面向け

---

### 5. コミットメッセージlint（commitlint）

**決定**: 不採用

**検討した選択肢**:
- commitlint + husky: コミット時に形式を自動チェック
- 不採用: 規則はドキュメントで定義、運用でカバー

**理由**:
- wipなど雑なコミットを許容したい場面がある
- 設定・管理コストに対してメリットが薄い
- 代替手段としてAIとのコミットメッセージ作成コマンドを用意する予定

---

## 保留事項

### デプロイ先選定

- 本番への手動デプロイ方針は決定済み
- デプロイ先（Render、Fly.io等）は別途議論して決定する
- 決定後にデプロイトリガー設定をGIT_STRATEGY.mdに追記

---

## 結果

[docs/GIT_STRATEGY.md](../GIT_STRATEGY.md) に運用ルールとして反映済み。

参考資料
https://zenn.dev/divsawa/articles/20251010-3_note-github-branch-myrules
https://qiita.com/okokok/items/76c3b93badaa383fae70
https://nvie.com/posts/a-successful-git-branching-model/
