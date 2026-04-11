# KakeMieru プロジェクト 全体概要

最終更新: 2026-01-16

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
Charts:     Chartkick + Chart.js
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

## 📊 機能設計（フェーズ別）

### フェーズ1: MVP（2-3週間）
**目標**: 最小限の動くアプリをデプロイ

**機能**:
- [ ] CSVアップロード機能
- [ ] 明細一覧表示
- [ ] カテゴリ自動分類（キーワードマッチ）
  - 例: "セブンイレブン" → 食費
  - 例: "JR東日本" → 交通費
- [ ] 月別集計グラフ
- [ ] カテゴリ別集計グラフ
- [ ] 前年同月比表示
- [ ] 月平均支出（カテゴリ別・全体）

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

---

### フェーズ2: 予算管理（2-3週間）
**目標**: 予算vs実績を可視化

**機能**:
- [ ] 収入設定
- [ ] カテゴリ別予算配分
  - 例: 食費 60,000円、交通費 20,000円
- [ ] 予算 vs 実績の比較表示
- [ ] 予算達成率グラフ
- [ ] 残額アラート
- [ ] 支出トレンド（増加・減少傾向の可視化）

**追加データモデル**:
```
MonthlyBudget（月次予算）
└─ BudgetItem（カテゴリ別予算項目）
```

**画面イメージ**:
```
2026年1月の予算
━━━━━━━━━━━━━━━
収入:        ¥300,000
総予算:      ¥280,000
実際の支出:  ¥265,000
残高:        ¥15,000 ✅

カテゴリ別
━━━━━━━━━━━━━━━
食費
予算: ¥60,000 | 実績: ¥58,000
残額: ¥2,000 ━━━━━━ 97%

交通費
予算: ¥20,000 | 実績: ¥22,000
残額: -¥2,000 ━━━━━━ 110% ⚠
```

---

### フェーズ3: 繰越・大型支出管理（1-2週間）
**目標**: 月をまたいだ管理

**機能**:
- [ ] 黒字繰越
  - 余った予算を翌月に繰り越し
  - 例: 食費2,000円余った → 翌月の食費予算に加算
  
- [ ] 赤字繰越
  - 使いすぎた分を翌月から差し引き
  - 例: 交通費2,000円オーバー → 翌月の交通費予算から減算

- [ ] キャッシュフロー予測（現在の支出パターンから将来残高を予測）
- [ ] 大型支出の分割払い管理
  - 例: MacBook 180,000円購入
  - 月々10,000円ずつ予算から引く
  - 残り返済期間を表示

**追加データモデル**:
```
Carryover（繰越）
LargeExpense（大型支出）
└─ Installment（分割払い明細）
```

---

### フェーズ4: ローカル自動取り込み（1週間）
**目標**: ローカル環境でもシンプルに動かせるようにする

**機能**:
- [ ] CLIコマンドによる取り込み（`rails import:run`）
  - 特定ディレクトリ（例: `~/kakemieru/import/`）のCSVを一括処理
  - 処理済みファイルを別ディレクトリへ移動
- [ ] フォルダウォッチャー（常駐プロセス）
  - 対象フォルダを監視し、CSVを置くと自動取り込み
  - バックグラウンドで動作

**背景**:
- Webアップロードに加えてローカルでも手軽に動かせる環境を提供
- ダウンロードしたCSVをフォルダに置くだけで完結させる

---

### フェーズ5: 認証・管理画面（1-2週間）
**目標**: セキュアな認証と管理者機能の実装

**機能**:
- [ ] パスキー認証（webauthn-rails）の追加（フェーズ1の Rails 8 Built-in を拡張）
  - フェーズ1で実装済みの Rails 8 Built-in に webauthn-rails → OmniAuth の順で追加
  - 詳細は [AUTHENTICATION.md](AUTHENTICATION.md) を参照
- [ ] 管理画面
  - ユーザー管理
  - 取り込み済みデータの確認・修正
  - カテゴリ分類ルールの管理
- [ ] `admin` フラグによる管理者権限制御

---

### フェーズ6: エクスポート（1週間）
**機能**:
- [ ] グラフを画像出力（PNG）
- [ ] スライド用レイアウト生成
- [ ] PDFレポート生成

---

## 🗄 データベース設計（詳細）

詳細は [DATABASE_DESIGN.md](DATABASE_DESIGN.md) を参照。

### フェーズ1のモデル構成

```
User
├─ has_many :payment_methods
├─ has_many :transactions       # user_id 直接保持
├─ has_many :imports
└─ has_many :categories         # user_id NOT NULL（コピー方式）

CategoryTemplate（システム共通テンプレート・不変）
                                # 登録時に categories にコピーされる

PaymentMethod（支払い手段: credit/debit/e_money/qr/cash）
├─ belongs_to :user
├─ has_many :transactions
└─ has_many :imports

Category（ユーザーごとのカテゴリ）
├─ belongs_to :user
└─ has_many :transactions

Transaction（明細 ※全期間を1テーブルで管理）
├─ belongs_to :user             # 直接保持（マルチテナント保証）
├─ belongs_to :payment_method
├─ belongs_to :import, optional: true
└─ belongs_to :category, optional: true
```

**設計方針**
- 明細は期間ごとに分けず全部 `transactions` テーブルに格納
- 「1ヶ月の明細」はクエリの `effective_date` 絞り込みで表現
- `transactions.user_id` を直接保持してマルチテナント分離をDB側で保証
- 詳細は [DATABASE_DESIGN.md](DATABASE_DESIGN.md) を参照

### カテゴリ自動分類のロジック
```ruby
def auto_categorize(description)
  case description
  when /コンビニ|スーパー|飲食/ then '食費'
  when /JR|メトロ|タクシー|バス/ then '交通費'
  when /映画|Netflix|Amazon Prime/ then '娯楽'
  when /電気|ガス|水道/ then '光熱費'
  when /docomo|au|SoftBank/ then '通信費'
  else '未分類'
  end
end
```

---

## 🚀 開発の進め方

### 基本方針
1. **シンプルから始める** - まず動くものを作る
2. **段階的に拡張** - 一度に詰め込まない
3. **TDD実践** - テストを先に書く
4. **こまめにコミット** - 小さい単位で記録
5. **工数を記録** - 見積もりと実績を比較

### Git運用

**ブランチ戦略**:
```
main
└─ feature/csv-upload
└─ feature/graph-display
└─ feature/budget-management
```

**コミットメッセージ**:
```bash
feat: CSVアップロード機能を追加
fix: カテゴリ分類のバグ修正
docs: データベース設計を追記
test: Transaction モデルのテスト追加
```

### Issue駆動開発
1. やりたいことをIssueに書く
2. ブランチを切る
3. 実装する
4. PRを作る（セルフレビュー）
5. マージする

### 工数管理
各Issueに記録:
```
見積もり: 4時間
実際: 6時間
学び: CSV解析に想定外の時間がかかった
```

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

## 🎯 重要な意思決定（ADR）

### 1. ホスティング: Fly.io を選択

**理由**:
- スケールゼロ対応でコストほぼ0（個人利用時）
- Dockerネイティブでローカルと本番環境が一致
- cold start 2〜5秒（Renderの30〜60秒より大幅に速い）
- 採用活動時にアップグレードで常時起動に切り替え可能

詳細は [ADR-0006](decisions/0006-hosting-strategy.md) を参照。

### 2. Docker化必須

**理由**:
- ベンダーロックイン回避
- 環境統一（ローカル = 本番）
- 将来の移行が容易

### 3. Public リポジトリ + MIT License

**理由**:
- ポートフォリオとして活用
- 投げ銭収益化が可能
- コードが見えることで信頼性UP

**注意**: 環境変数は絶対コミットしない

### 4. GitHub のみでドキュメント管理

**理由**:
- ツールの分散を避ける
- Git履歴に残る
- コードと同じ場所で管理

**使用機能**:
- Issues（タスク管理）
- Projects（進捗管理）
- Actions（CI/CD）

---

## 📁 プロジェクト構造
```
kakemieru/
├── README.md              # プロジェクト概要（外向け）
├── TODO.md                # タスク一覧
├── docs/
│   └── PROJECT_OVERVIEW.md  # このファイル
├── .claude/
│   └── instructions.md    # Claude Code用の指示書
├── decisions/             # 意思決定記録（ADR）
│   ├── 001-hosting-selection.md
│   ├── 002-docker-strategy.md
│   ├── 003-documentation-strategy.md
│   └── 004-repository-visibility.md
├── Dockerfile
├── docker-compose.yml
├── .gitignore
├── LICENSE               # MIT License
└── （Railsプロジェクト - これから作成）
```

---

## ⏭ 次のステップ（直近）

### 今週やること
1. [ ] GitHubリポジトリ作成（Public）
2. [ ] Dockerfile 作成
3. [ ] docker-compose.yml 作成
4. [ ] Rails プロジェクト初期化
5. [ ] PostgreSQL接続確認

### 来週やること
1. [ ] データベース設計
2. [ ] User/PaymentMethod/Import/Category/Transaction モデル作成
3. [ ] CSVアップロード機能（基本）
4. [ ] 明細一覧表示

---

## 🔗 参考リンク

- **Fly.io**: https://fly.io/
- **Rails Guides**: https://guides.rubyonrails.org/
- **Docker公式**: https://docs.docker.com/

---

## 📝 メモ・検討中の事項

### 将来的な機能アイデア
- [ ] 複数カード対応（優先度高）
- [ ] レシート読み取り（OCR）
- [ ] 銀行口座連携（技術的に難しい）
- [ ] 資産推移グラフ
- [ ] 他ユーザーとの比較（匿名）

### 技術的な検討事項
- [ ] CSV フォーマットの多様性への対応
- [ ] カテゴリ分類の精度向上（機械学習？）
- [ ] リアルタイムグラフ更新（WebSocket）
- [ ] モバイルアプリ化（React Native）

---

**このドキュメントを更新する時**:
- 新しい機能を追加したら
- 重要な決定をしたら
- フェーズが完了したら

**最終更新**: 2026-01-16
