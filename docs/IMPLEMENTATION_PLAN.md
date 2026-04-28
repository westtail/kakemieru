# 実装計画

フェーズ1（MVP）の実装タスク一覧・Issue 管理方針・開発順序の記録。

---

## Issue 管理方針

### Issue の種類

| タグ | 内容 |
|---|---|
| （なし） | 機能実装 + ユニット/リクエスト spec |
| `[migration]` | マイグレーション実装 + `db:migrate` / `db:rollback` / `db:migrate:redo` 確認 |
| `[e2e]` | Capybara + Cuprite によるブラウザ自動テスト |
| `[deploy]` | Fly.io デプロイ + 手動動作確認 |

### PR 粒度

- 1 Issue = 1 PR を基本とする
- diff が大きくなりすぎる場合は Issue を分割して対応済み

### マイグレーション確認チェックリスト（全 `[migration]` Issue 共通）

```
- [ ] rails db:migrate が正常完了すること
- [ ] rails db:rollback で down が正常動作すること
- [ ] rails db:migrate:redo (up→down→up) が通ること
- [ ] db/schema.rb のレビュー（カラム・インデックス・制約を確認）
```

---

## セッション構成と Issue 一覧

### S0: 開発環境整備・E2E 環境

| # | タイトル |
|---|---|
| [#55](https://github.com/westtail/kakemieru/issues/55) | 開発環境整備（letter_opener / annotate / seeds / CI セキュリティ） |
| [#54](https://github.com/westtail/kakemieru/issues/54) | [e2e] E2E テスト環境構築（Capybara + Cuprite + Docker Chrome） |

### S1: 基盤

| # | タイトル |
|---|---|
| [#15](https://github.com/westtail/kakemieru/issues/15) | SimpleCov 設定（カバレッジ目標 80%） |
| [#16](https://github.com/westtail/kakemieru/issues/16) | [migration] users / sessions テーブル |
| [#17](https://github.com/westtail/kakemieru/issues/17) | User モデル + spec |
| [#18](https://github.com/westtail/kakemieru/issues/18) | 認証コントローラ・ビュー + spec（ログイン・ログアウト） |

### S2: アカウント管理

| # | タイトル |
|---|---|
| [#19](https://github.com/westtail/kakemieru/issues/19) | サインアップ画面 + 自動生成 + spec |
| [#20](https://github.com/westtail/kakemieru/issues/20) | パスワードリセット + spec |
| [#21](https://github.com/westtail/kakemieru/issues/21) | アカウント設定・退会 + spec |
| [#22](https://github.com/westtail/kakemieru/issues/22) | [deploy] S1-S2 Fly.io デプロイ・認証フロー実機確認 |
| [#56](https://github.com/westtail/kakemieru/issues/56) | [e2e] 認証フロー E2E テスト |

### S3: カテゴリ管理

| # | タイトル |
|---|---|
| [#23](https://github.com/westtail/kakemieru/issues/23) | [migration] category_templates / categories テーブル + シード |
| [#24](https://github.com/westtail/kakemieru/issues/24) | CategoryTemplate・Category モデル + spec |
| [#25](https://github.com/westtail/kakemieru/issues/25) | カテゴリ管理画面 CRUD + spec |

### S4: 支払方法管理

| # | タイトル |
|---|---|
| [#26](https://github.com/westtail/kakemieru/issues/26) | [migration] payment_methods テーブル |
| [#27](https://github.com/westtail/kakemieru/issues/27) | PaymentMethod モデル + spec |
| [#28](https://github.com/westtail/kakemieru/issues/28) | 支払方法管理画面 CRUD + spec |
| [#29](https://github.com/westtail/kakemieru/issues/29) | 支払方法削除・アーカイブ Turbo Stream + spec |
| [#30](https://github.com/westtail/kakemieru/issues/30) | [deploy] S3-S4 Fly.io デプロイ・カテゴリ・支払方法実機確認 |

### S5: CSV インポート基盤

| # | タイトル |
|---|---|
| [#31](https://github.com/westtail/kakemieru/issues/31) | [migration] imports / merchant_classifications テーブル |
| [#32](https://github.com/westtail/kakemieru/issues/32) | Import モデル + spec |
| [#33](https://github.com/westtail/kakemieru/issues/33) | 楽天カード CSV パーサー + spec |

### S6: CSV インポート画面

| # | タイトル |
|---|---|
| [#34](https://github.com/westtail/kakemieru/issues/34) | アップロード画面・保存処理 + spec |
| [#35](https://github.com/westtail/kakemieru/issues/35) | カテゴリ自動割り当て + spec |
| [#36](https://github.com/westtail/kakemieru/issues/36) | 手動まとめ入力 + spec |
| [#37](https://github.com/westtail/kakemieru/issues/37) | [deploy] S5-S6 Fly.io デプロイ・CSV インポート実機確認 |
| [#57](https://github.com/westtail/kakemieru/issues/57) | [e2e] CSV インポート E2E テスト |

### S7: 明細基盤

| # | タイトル |
|---|---|
| [#38](https://github.com/westtail/kakemieru/issues/38) | [migration] transactions テーブル |
| [#39](https://github.com/westtail/kakemieru/issues/39) | Transaction モデル + spec |
| [#40](https://github.com/westtail/kakemieru/issues/40) | 手動1件入力（/transactions/new）+ spec |

### S8: 明細画面

| # | タイトル |
|---|---|
| [#41](https://github.com/westtail/kakemieru/issues/41) | 明細一覧・絞り込みバー + spec |
| [#42](https://github.com/westtail/kakemieru/issues/42) | 明細編集 + spec |
| [#43](https://github.com/westtail/kakemieru/issues/43) | カテゴリ即時変更・削除 Turbo Stream + spec |
| [#44](https://github.com/westtail/kakemieru/issues/44) | [deploy] S7-S8 Fly.io デプロイ・明細操作実機確認 |
| [#58](https://github.com/westtail/kakemieru/issues/58) | [e2e] 明細管理 E2E テスト |

### S9: 履歴・サマリー API

| # | タイトル |
|---|---|
| [#45](https://github.com/westtail/kakemieru/issues/45) | 取り込み履歴一覧・詳細 + spec |
| [#46](https://github.com/westtail/kakemieru/issues/46) | 取り込み取り消し + spec |
| [#47](https://github.com/westtail/kakemieru/issues/47) | サマリー API（GET /transactions/summary）+ spec |

### S10: ダッシュボード・仕上げ

| # | タイトル |
|---|---|
| [#48](https://github.com/westtail/kakemieru/issues/48) | ダッシュボード UI（Stimulus + Chart.js）+ spec |
| [#49](https://github.com/westtail/kakemieru/issues/49) | [migration] 予算関連テーブル定義（フェーズ2用） |
| [#50](https://github.com/westtail/kakemieru/issues/50) | フロントエンド横断（レイアウト・ナビ・Stimulus 共通） |
| [#51](https://github.com/westtail/kakemieru/issues/51) | 共通横断（エラーページ・ヘルスチェック・N+1・CSRF） |
| [#52](https://github.com/westtail/kakemieru/issues/52) | README.md 作成 |
| [#53](https://github.com/westtail/kakemieru/issues/53) | [deploy] 全フロー通し実機確認 |

---

## 推奨実装順序

```
S0（開発環境整備 → E2E 環境構築）
  ↓
S1（SimpleCov → users/sessions マイグレーション → User モデル → 認証画面）
  ↓
S2（サインアップ → パスワードリセット → アカウント設定）
  ↓ [deploy] 認証フロー実機確認 + [e2e] 認証 E2E
  ↓
S3（カテゴリ） → S4（支払方法）
  ↓ [deploy] カテゴリ・支払方法実機確認
  ↓
S5（CSV 基盤） → S6（CSV 画面）
  ↓ [deploy] CSV インポート実機確認 + [e2e] CSV E2E
  ↓
S7（明細基盤） → S8（明細画面）
  ↓ [deploy] 明細操作実機確認 + [e2e] 明細 E2E
  ↓
S9（履歴・API） → S10（ダッシュボード・仕上げ）
  ↓ [deploy] 全フロー通し実機確認
```

---

## 関連 ADR

| ADR | 内容 |
|---|---|
| [ADR-0010](decisions/0010-testing-framework.md) | テストフレームワーク（RSpec 採用） |
| [ADR-0022](decisions/0022-e2e-testing-strategy.md) | E2E テスト戦略（Capybara + Cuprite 採用） |
