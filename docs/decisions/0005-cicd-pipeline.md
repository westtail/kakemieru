# ADR-0005: CI/CDパイプライン構成

- 日付: 2026-03-21
- ステータス: 決定済み

---

## コンテキスト

テスト・Lint・デプロイの自動化方法を決定する必要があった。
「機能開発に入る前にパイプラインを完成させる」方針のもと、SRE的に運用基盤を整える。

---

## 決定事項

### 1. CIツール

**決定**: GitHub Actions を使用する

**理由**:
- GitHubリポジトリとの統合がシンプル
- 無料枠で個人開発は十分
- 設定がYAMLで管理でき、Gitの履歴に残る

---

### 2. ワークフロー構成

**決定**: 2つのワークフローファイルに分ける

| ファイル | トリガー | 内容 |
|---|---|---|
| `.github/workflows/ci.yml` | PRの作成・更新、developへのpush | テスト・Lint |
| `.github/workflows/deploy.yml` | タグpush（`v*`） | Renderへデプロイ |

**理由**:
- CI（品質チェック）とCD（デプロイ）を明確に分離する
- PRのたびにデプロイが走るのを防ぐ

---

### 3. CIで実行すること

**決定**: テスト実行とLintチェックの2段階

```
ci.yml
├── Step 1: テスト実行（RSpec）
└── Step 2: Lintチェック（RuboCop）
```

**理由**:
- テストが通らないコードをdevelopに入れない
- コードスタイルを統一する

---

### 4. デプロイトリガー

**決定**: リリースタグ（`v*`）のpushで発火する

```bash
git tag v1.0.0
git push origin v1.0.0
# → deploy.yml が実行される → Render へデプロイ
```

**検討した選択肢**:
- mainブランチへのpushで自動デプロイ
- リリースタグで手動トリガー ← **採用**
- workflow_dispatchで手動実行

**理由**:
- mainマージ直後に即デプロイは意図しないリリースのリスクがある
- タグ = リリース記録になり、GitHubのReleasesページに履歴が残る
- 業務でも同様の運用に慣れており認知コストが低い

---

### 5. バージョニング

**決定**: SemVer（Semantic Versioning）に準拠する

| 変更の種類 | 上げる桁 | 例 |
|---|---|---|
| 後方互換のバグ修正 | patch | v1.0.0 → v1.0.1 |
| 後方互換の新機能 | minor | v1.0.0 → v1.1.0 |
| 破壊的変更 | major | v1.0.0 → v2.0.0 |

初回リリースは `v0.1.0` とする。

---

### 6. デプロイ方法

**決定**: `flyctl` を使ったGitHub Actionsステップ

```yaml
- name: Deploy to Fly.io
  uses: superfly/flyctl-actions/setup-flyctl@master
- run: flyctl deploy --remote-only
  env:
    FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

**理由**:
- Fly.io公式のGitHub Actionを使うだけでシンプル
- `FLY_API_TOKEN`のみで認証が完結する

---

## 結果

[docs/infra/INITIAL_SETUP.md](../infra/INITIAL_SETUP.md) にセットアップ手順として反映済み。
