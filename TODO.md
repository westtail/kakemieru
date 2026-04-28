# TODO / ロードマップ

開発フェーズごとのタスク一覧。実装単位は GitHub Issues で管理する。

---

## 現在のフェーズ: 基盤整備

- [x] Rails 8 プロジェクト初期化
- [x] Docker / docker-compose 環境構築
- [x] PostgreSQL 接続
- [x] Fly.io デプロイ設定
- [x] GitHub Actions CI 構築
- [x] RSpec + FactoryBot 導入
- [x] CLAUDE.md 作成

### 初期セットアップ完了チェックリスト

- [x] ローカルで `docker compose up` が起動する
- [x] `http://localhost:3000` で Rails のデフォルト画面が表示される
- [x] `rails db:create` が成功する
- [x] Fly.io アプリが作成されている
- [x] GitHub Secrets が設定されている
- [x] ブランチ保護が設定されている
- [x] タグ push でデプロイが実行される
- [x] 本番 URL でアプリが表示される

## 完了済み

- [x] ホスティング選定（Fly.io） → ADR 参照
- [x] テストフレームワーク選定（RSpec） → ADR-001

---

## フェーズ1: MVP

**目標**: CSV をアップロードして明細一覧とグラフを見られる状態

Issue の種類:
- 通常 Issue: 機能実装 + テスト
- [migration] マイグレーション Issue: 実装 + migrate / rollback / redo 確認
- [deploy] 実機確認 Issue: Fly.io デプロイ + 手動動作確認
- [e2e] E2E テスト Issue: Capybara + Cuprite によるブラウザ自動テスト

---

### S0: 開発環境整備

- [ ] letter_opener 導入（開発環境でメールをブラウザ表示）
- [ ] annotate 導入（マイグレーション後にモデルへスキーマコメント自動追記）
- [ ] `db/seeds.rb` 開発用サンプルデータ（ユーザー・明細数件）
- [ ] Brakeman + bundler-audit を CI（GitHub Actions）に追加

### S0: E2E テスト環境

- [ ] [e2e] Capybara + Cuprite セットアップ（RSpec に統合）
- [ ] [e2e] Docker に Chrome（headless）を追加
- [ ] [e2e] 認証フロー E2E テスト（登録・ログイン・ログアウト）
- [ ] [e2e] CSV インポート E2E テスト（アップロード〜明細表示）
- [ ] [e2e] 明細管理 E2E テスト（絞り込み・編集・削除）

---

### S1: 基盤

- [ ] SimpleCov 設定（目標カバレッジ 80%）
- [ ] [migration] users / sessions テーブル
- [ ] User モデル + spec（バリデーション・has_secure_password・has_many）
- [ ] 認証コントローラ・ビュー + spec（ログイン・ログアウト）

### S2: アカウント管理

- [ ] サインアップ画面 + 自動生成（PaymentMethod「現金」・categories）+ spec
- [ ] パスワードリセット（メール送信 + トークン）+ spec
- [ ] アカウント設定（メール変更・パスワード変更）・退会 + spec
- [ ] [deploy] S1-S2 Fly.io デプロイ・認証フロー実機確認

### S3: カテゴリ管理

- [ ] [migration] category_templates / categories テーブル + シード（12カテゴリ）
- [ ] CategoryTemplate・Category モデル + spec
- [ ] カテゴリ管理画面 CRUD + spec

### S4: 支払方法管理

- [ ] [migration] payment_methods テーブル
- [ ] PaymentMethod モデル + spec（enum・アーカイブスコープ・削除ロジック）
- [ ] 支払方法管理画面 CRUD + spec
- [ ] 削除・アーカイブ Turbo Stream + spec
- [ ] [deploy] S3-S4 Fly.io デプロイ・カテゴリ・支払方法実機確認

### S5: CSV インポート基盤

- [ ] [migration] imports / merchant_classifications テーブル
- [ ] Import モデル + spec（enum・バリデーション・重複チェック）
- [ ] 楽天カード CSV パーサー + spec（Shift-JIS→UTF-8・ヘッダー検出・金額カンマ除去）

### S6: CSV インポート画面

- [ ] アップロード画面・保存処理 + spec（file_hash 重複チェック・Turbo Stream）
- [ ] カテゴリ自動割り当て + spec（merchant_classifications 参照）
- [ ] 手動まとめ入力 + spec（source_type: manual_bulk）
- [ ] [deploy] S5-S6 Fly.io デプロイ・実際のカード明細 CSV で実機確認

### S7: 明細基盤

- [ ] [migration] transactions テーブル（GENERATED カラム・複合インデックス・FK 制約）
- [ ] Transaction モデル + spec（バリデーション・スコープ: in_month / not_deleted）
- [ ] 手動1件入力（/transactions/new）+ spec

### S8: 明細画面

- [ ] 明細一覧・絞り込みバー（月 / カテゴリ / キーワード）+ spec
- [ ] 明細編集（CSV 原本は表示のみ・訂正値のみ編集）+ spec
- [ ] カテゴリ即時変更・削除 Turbo Stream + spec
- [ ] [deploy] S7-S8 Fly.io デプロイ・明細操作実機確認

### S9: 履歴・サマリー API

- [ ] 取り込み履歴一覧・詳細 + spec
- [ ] 取り込み取り消し + spec
- [ ] サマリー API（GET /transactions/summary?month=YYYY-MM）+ spec

### S10: ダッシュボード・仕上げ

- [ ] ダッシュボード UI（Stimulus + fetch + Chart.js）+ spec
- [ ] フロントエンド横断（レイアウト・グローバルナビ・Stimulus 共通コントローラ）
- [ ] [migration] 予算関連テーブル定義のみ（budget_templates / budget_items / monthly_budgets / carryovers）
- [ ] 共通横断（エラーページ 404/422/500・ヘルスチェック・N+1 対策・CSRF 設定）
- [ ] README.md 作成
- [ ] [deploy] 全フロー通し実機確認

---

## フェーズ2: 予算管理

**目標**: 予算 vs 実績を可視化する

- [ ] 予算テンプレート管理（/budget_templates）
- [ ] 月別予算設定（/budgets）
- [ ] 予算 vs 実績の比較表示
- [ ] 持ち越し確定機能（冪等性保証）
- [ ] 予算達成率グラフ

---

## フェーズ3: 繰越・大型支出管理

**目標**: 月をまたいだ管理

- [ ] 黒字繰越（余った予算を翌月に加算）
- [ ] 赤字繰越（使いすぎ分を翌月から差し引き）
- [ ] 大型支出の分割払い管理

---

## フェーズ4: エクスポート

- [ ] グラフを PNG 出力
- [ ] PDF レポート生成

---

## バックログ（優先度未定）

- [ ] 複数カード対応
- [ ] レシート読み取り（OCR）
- [ ] 資産推移グラフ
- [ ] モバイル対応
