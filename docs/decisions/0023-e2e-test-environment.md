# ADR-0023: E2E テスト環境（Cuprite + 専用 Chrome コンテナ）

- 日付: 2026-07-08
- ステータス: 提案中
- 関連: [ADR-0010 テストフレームワーク](0010-testing-framework.md) / [ADR-0022 S1 認証基盤の実装計画](0022-s1-auth-foundation-plan.md)
- 対象 Issue: #55（環境構築） / 後続 #54（認証フロー E2E）

---

## コンテキスト

認証フロー（登録・ログイン・ログアウト・パスワードリセット・退会）を実ブラウザで
検証するシステム spec を書きたい（#54）。その前提として、RSpec に統合した
E2E テスト環境を構築する（#55）。

ユニット spec（モデル）・リクエスト spec（コントローラ）はブラウザ不要で構築済みだが、
JS を含む画面操作・リダイレクト・表示確認を通しで検証するにはブラウザdriverが要る。

---

## 論点と決定

### 1. ドライバは Cuprite（Ferrum / CDP）を採用（決定）

| 選択肢 | 概要 | 評価 |
|---|---|---|
| **Cuprite** | Ferrum 経由で Chrome を CDP 直接操作。WebDriver 不要 | 高速・依存が少ない・待機が安定。採用 |
| Selenium | WebDriver 経由。`selenium/standalone-chrome` が定番 | 実績豊富だが webdriver 層のオーバーヘッド・設定が重い |

Issue #55 は当初 `selenium/standalone-chrome` を挙げていたが、これは Selenium 用イメージで
CDP 直結の Cuprite とは噛み合わない。**Cuprite を採用し、Chrome の用意方法を 2 に合わせる。**

### 2. Chrome は CDP を公開する専用コンテナ（決定）

`docker-compose.override.yml` に Chrome サービスを追加し、CDP（リモートデバッグ）を
`0.0.0.0:9222` で公開する。テストプロセス（web コンテナ）から Ferrum が
`http://chrome:9222` で接続する。

- 「別サービスで Chrome を用意する」という Issue の設計意図は維持
- web/test コンテナに Chromium を同梱する案は不採用（イメージ肥大・本番イメージへの混入リスク）
- ローカル専用の override に置くことで**本番・CI の基本定義（docker-compose.yml）には影響させない**

### 3. コンテナ間ネットワーク（決定）

システム spec では Capybara がテストプロセス内でアプリsサーバ（Puma）を起動し、
Chrome コンテナがそこへアクセスする。Docker 越しに疎通させるため:

- `Capybara.server_host = "0.0.0.0"`（web コンテナの全 IF で待受け、chrome から到達可能に）
- `Capybara.app_host = "http://web:<port>"`（chrome から web コンテナ名で解決）
- `Capybara.server_port` を固定（例: 4444）し app_host と一致させる
- Ferrum は `url: "http://chrome:9222"` でリモート Chrome に接続

### 4. spec 分類とタグ（決定）

- システム spec は `spec/features/` に置き `type: :feature` で登録
- Cuprite ドライバを既定にし、JS 実行を伴う E2E を全て実ブラウザで走らせる
- ユニット/リクエスト spec（非ブラウザ）とは実行経路を分離

### 5. 失敗時スクリーンショット（決定）

- 保存先 `tmp/screenshots/`（gitignore）
- example 失敗時に自動保存し、原因調査に使う

---

## テスト方針

- 環境構築の検証は **home 画面へのスモーク feature spec**（`/` を訪問し文言を確認）で行う。
  認証実装前でも E2E パイプライン全体（Capybara → Chrome → web → レスポンス）を通せる。
- 完了条件（#55）: `bundle exec rspec spec/features/` が実行でき、失敗時にスクショが残る。

---

## 影響・結果

- 追加 gem（test グループ）: `capybara` / `cuprite`
- 追加ファイル: `docker-compose.override.yml`（chrome サービス）/ `spec/support/capybara.rb` /
  `spec/support/helpers/authentication_helper.rb` / `spec/features/` / `.gitignore`（tmp/screenshots）
- CI（GitHub Actions）でも system spec を実行する（#54 で対応）。CI はネイティブ実行で
  ubuntu-latest にプリインストールされた Chrome を Cuprite が**ローカル起動**する方式にした。
  `spec/support/capybara.rb` は `CHROME_HOST`（docker-compose.override が付与）の有無で
  「リモート（ローカル Docker・別コンテナ Chrome）/ ローカル（CI・同一ホスト Chrome）」を切り替える。

---

## 参考

- [Modern web testing with Cuprite | Evil Martians](https://evilmartians.com/chronicles/system-of-a-test-setting-up-end-to-end-rails-testing)
- [Cuprite (GitHub)](https://github.com/rubycdp/cuprite)
- [Ferrum (GitHub)](https://github.com/rubycdp/ferrum)
