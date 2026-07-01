# KakeMieru プロジェクト概要

---

## 📋 プロジェクト基本情報

### プロジェクト名

**KakeMieru（家計見える）**

### 一言で言うと

クレジットカードの明細CSVをアップロードして、収支をグラフで「見える化」する家計簿Webアプリ

### 現状の課題

- 毎月クレジットカード明細をCSVでダウンロード
- Excelで手作業で管理・集計
- 時間がかかる、面倒、ミスも起きる

### 解決方法

- CSVアップロードするだけで自動集計
- 月別・カテゴリ別にグラフ表示
- 予算管理・繰越機能も追加予定

---

## 🎯 開発の目的

### 1. 個人的な課題解決

実際に自分が困っている問題を解決する

### 2. 技術習得・実践

- Railsの再学習
- TDD（テスト駆動開発）
- Docker環境構築
- CI/CD構築
- Issue駆動開発
- 工数見積もりと測定

### 3. ポートフォリオ作成

就職・転職活動で見せられる成果物

### 4. 小規模収益化

サーバー代ペイ程度（月1,500-3,000円）を投げ銭で

---

## 🛠 技術スタック

### v1（現在開発予定）

```
Backend:    Ruby on Rails 8
Database:   PostgreSQL
Frontend:   Hotwire (Turbo + Stimulus)
JS:         importmap
CSS:        Tailwind CSS
Charts:     Chart.js（Stimulus + fetch で直接描画）
Container:  Docker + docker-compose
Hosting:    Fly.io（スケールゼロ → 採用活動時にアップグレード）
CI/CD:      GitHub Actions
```

### v2（将来のリプレイス）

```
Frontend:   React
Backend:    Go
API:        RESTful / GraphQL
```

将来的にモノリスからSPAへリプレイスして、技術経験を積む

---

## 💰 収益化の考え方

### 目標

**サーバー代をペイする程度（月1,500-3,000円）**

### 方法

**投げ銭モデル**

- Buy Me a Coffee
- GitHub Sponsors

### 期待値

```
ユーザー: 50-100人
月に2-5人が投げ銭: 500-1,000円/回
合計: 月1,000-3,000円
```

### 優先順位

```
1. 学習・技術習得（最優先）
2. ポートフォリオ作成
3. サーバー代ペイ（おまけ程度）
```

**フルタイム起業は想定していない**:

- 競合が強すぎる（マネーフォワード、Zaimなど）
- 差別化が困難
- マーケティングコストが高い

**でも間接的な価値は大きい**:

- 就職・転職で年収UP（+50-200万円）
- 副業案件の受注（月5-20万円）
- 技術力の証明

---

## 📊 機能要件（フェーズ別）

タスク単位の TODO は [TODO.md](../TODO.md) を参照。

### フェーズ1: MVP

**目標**: CSV をアップロードして明細一覧とグラフを見られる状態

- CSV アップロード機能（楽天カード CSV。詳細は [ADR-0012](decisions/0012-csv-import-strategy.md)）
- 明細一覧表示
- カテゴリ自動分類（キーワードマッチ。詳細は [CATEGORY_CLASSIFICATION.md](design/CATEGORY_CLASSIFICATION.md)）
- 月別集計グラフ／カテゴリ別集計グラフ
- 前年同月比表示
- 月平均支出（カテゴリ別・全体）

**データモデル**:

```
User（ユーザー）
├─ PaymentMethod（支払い手段: クレカ・QR・現金など）
├─ Import（CSV取り込み履歴）
├─ Category（カテゴリ・user_id NOT NULL）
└─ Transaction（明細・user_id 直接保持）
    ├─ belongs_to :user
    ├─ belongs_to :payment_method
    ├─ belongs_to :import (optional)
    └─ belongs_to :category (optional)
```

詳細は [DATABASE_DESIGN.md](design/DATABASE_DESIGN.md) を参照。

### フェーズ2: 予算管理

**目標**: 予算 vs 実績を可視化

- 収入設定
- カテゴリ別予算配分
- 予算 vs 実績の比較表示・予算達成率グラフ
- 残額アラート
- 支出トレンド（増加・減少傾向の可視化）

**追加データモデル**: `MonthlyBudget`（月次予算）/ `BudgetItem`（カテゴリ別予算項目）

### フェーズ3: 繰越・大型支出管理

**目標**: 月をまたいだ管理

- 黒字繰越（余った予算を翌月に加算）
- 赤字繰越（使いすぎ分を翌月から差し引き）
- キャッシュフロー予測（現在の支出パターンから将来残高を予測）
- 大型支出の分割払い管理（例: 18万円の買い物を月1万円ずつ予算から引き、残り返済期間を表示）

**追加データモデル**: `Carryover`（繰越）/ `LargeExpense`（大型支出）/ `Installment`（分割払い明細）

### フェーズ4: ローカル自動取り込み

**目標**: ローカル環境でもシンプルに動かせるようにする

- CLI コマンドによる取り込み（`rails import:run`。特定ディレクトリの CSV を一括処理し、処理済みファイルを別ディレクトリへ移動）
- フォルダウォッチャー（常駐プロセスが対象フォルダを監視し、CSV を置くと自動取り込み）

Web アップロードに加えて、ダウンロードした CSV をフォルダに置くだけで完結する手軽な導線を提供する。

### フェーズ5: 認証・管理画面

**目標**: セキュアな認証と管理者機能の実装

- パスキー認証（webauthn-rails）の追加。フェーズ1の Rails 8 Built-in を拡張する形で webauthn-rails → OmniAuth の順に対応（詳細は [AUTHENTICATION.md](design/AUTHENTICATION.md)）
- 管理画面（ユーザー管理／取り込み済みデータの確認・修正／カテゴリ分類ルールの管理）
- `admin` フラグによる管理者権限制御

### フェーズ6: エクスポート

- グラフを画像出力（PNG）
- スライド用レイアウト生成
- PDF レポート生成

---

## 🔒 非機能要件

| 区分 | 要件 |
|---|---|
| セキュリティ | パスワードは bcrypt でハッシュ化（Rails 8 built-in authentication）。環境変数はコミットしない。CSRF 対策・HTTPS（Fly.io）を必須とする |
| マルチテナント分離 | `transactions.user_id` を直接保持し、DB クエリレベルでユーザー間のデータ漏洩を防ぐ（詳細は [DATABASE_DESIGN.md](design/DATABASE_DESIGN.md)） |
| 可用性 | Fly.io のスケールゼロ運用を前提とし、個人利用時はコストを最小化。cold start は 2〜5 秒程度を許容 |
| パフォーマンス | N+1 クエリ対策、明細テーブルへの複合インデックス設計（[DATABASE_DESIGN.md](design/DATABASE_DESIGN.md)） |
| ブラウザ対応 | 最新版の Chrome / Safari / Firefox / Edge を対象とする |
| レスポンシブ対応 | Tailwind CSS によりモバイル〜デスクトップの主要画面幅に対応 |
| データ保全 | CSV 原本は明細編集後も不変保存し、訂正値のみ別カラムで管理する |

---

## 📚 関連ドキュメント

- [TODO.md](../TODO.md) — タスク一覧・ロードマップ
- [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) — 開発の進め方・Git運用
- [docs/decisions/](decisions/) — 重要な技術的意思決定（ADR）
- [docs/research/market/](research/market/README.md) — 競合の市場調査
