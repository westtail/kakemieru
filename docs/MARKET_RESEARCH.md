# 市場調査：家計簿・明細管理サービス

最終更新: 2026-04-05

---

## 概要

クレジットカード明細のCSVアップロード・管理を軸とした家計簿サービスの市場調査。
KakeMieru の設計・機能検討の参考資料として作成。

---

## 歴史的背景

### スクレイピング時代（〜2018年）

マネーフォワード・Zaim など初期の家計簿サービスは、**ユーザーのネットバンキングID・パスワードを預かり、サーバー側でログイン代行するスクレイピング方式**で明細を取得していた。

- ユーザーの認証情報をサービス側で保管する必要があり、セキュリティリスクが存在
- 利用規約上のグレーゾーンとなるケースも多かった
- マネーフォワードは2019年時点で35銀行、2020年6月には111銀行とAPI契約を締結

### 銀行法改正（2018年）

2018年6月施行の改正銀行法により、電子決済等代行業者の登録制度が整備された。
これを機にマネーフォワード・Zaimなどは段階的にスクレイピングからAPI連携へ移行。

### 現在

- 大手サービスは金融機関との正式なAPI契約で明細を取得
- 個人開発レベルで公式APIにアクセスする手段はほぼない
- **CSV手動アップロード**は引き続き全サービスで対応している基本機能

---

## 国内サービス

### マネーフォワード ME

- **URL**: https://moneyforward.com/
- **概要**: 銀行・カード・証券など2,600以上の金融機関と連携できる国内最大手の家計簿サービス
- **CSV対応**: あり（明細アップロード）
- **主な機能**
  - 銀行・カード自動連携
  - 資産管理・推移グラフ
  - カテゴリ自動分類
  - 家計レポート
- **料金**: 無料版（連携口座数制限あり）/ プレミアム月500円〜
- **備考**: B2B向けに会計ソフト「マネーフォワード クラウド」も展開

### Zaim

- **URL**: https://zaim.net/
- **概要**: 2011年サービス開始。創業者・閑歳孝子氏が個人で開発してリリースした家計簿サービス
- **CSV対応**: あり
- **主な機能**
  - 自動カテゴリ分類
  - 複数カード・口座対応
  - レシート撮影
  - グラフ分析
- **料金**: 無料版 / プレミアムあり
- **備考**: 2013年10月時点で100万ユーザー突破。個人開発からスケールした事例として参考になる

### freee

- **URL**: https://www.freee.co.jp/
- **概要**: 中小企業・個人事業主向けのクラウド会計ソフト
- **CSV対応**: あり（明細アップロード）
- **主な機能**
  - 自動仕訳・会計処理
  - 確定申告対応
  - 請求書作成
- **料金**: 有料（月額プラン）

### 弥生会計

- **URL**: https://www.yayoi-kk.co.jp/
- **概要**: 老舗の会計ソフト。クラウド版でCSV取り込みに対応
- **CSV対応**: あり
- **料金**: 有料

---

## 海外サービス

### YNAB（You Need A Budget）

- **URL**: https://www.ynab.com/
- **概要**: 独自の予算管理メソッド「YNAB四則法則」で根強いファンを持つ米国発サービス
- **CSV対応**: あり（ファイルベースインポート）
- **主な機能**
  - 独自予算管理メソッド
  - カテゴリ分類
  - リアルタイム同期
- **料金**: サブスクリプション型（月額/年額）
- **備考**: 熱狂的なユーザーコミュニティが特徴

### Lunch Money

- **URL**: https://lunchmoney.app/
- **概要**: 個人開発者が作り SaaS として成立させたサービス。KakeMieru に方向性が近い
- **CSV対応**: あり（CSV・PDF両対応）
- **主な機能**
  - CSV/PDFアップロード
  - 開発者向けAPI提供
  - 支出の詳細分析
  - カテゴリ分類
- **料金**: サブスクリプション型
- **備考**: 個人開発者が作ってマネタイズに成功した事例として参考になる

### Firefly III

- **URL**: https://www.firefly-iii.org/
- **概要**: オープンソースのセルフホスト型家計簿アプリ
- **CSV対応**: あり
- **主な機能**
  - ルールベース自動分類
  - 複数口座管理
  - APIあり
- **料金**: 無料（セルフホスト）
- **備考**: OSSなのでコードが参考になる

### Actual Budget

- **URL**: https://actualbudget.org/
- **概要**: オープンソースのローカルファーストな家計簿アプリ
- **CSV対応**: あり（QIF/OFX/CSV対応）
- **主な機能**
  - ルールベース自動分類
  - 予算管理
  - リアルタイム同期
- **料金**: 無料（オープンソース）

### Copilot Money

- **URL**: https://copilot.money/
- **概要**: Mint（2023年閉鎖）からの移行ユーザーを取り込んだ iOS/Mac ネイティブアプリ
- **CSV対応**: あり（Apple Card専用スプレッドシート取り込みも対応）
- **主な機能**
  - カテゴリ自動分類
  - Mint移行機能
  - グラフ分析
- **料金**: 無料版・有料版あり

### Monarch Money

- **URL**: https://www.monarchmoney.com/
- **概要**: Mint閉鎖後に急成長した米国の家計簿サービス
- **CSV対応**: あり（CSV/OFX対応）
- **主な機能**
  - 資産追跡
  - 支出分析
  - 予算管理
- **料金**: サブスクリプション型

### PocketSmith

- **URL**: https://www.pocketsmith.com/
- **概要**: グローバル対応を売りにしたニュージーランド発の家計簿サービス
- **CSV対応**: あり（OFX/QIF/CSV対応）
- **主な機能**
  - 将来キャッシュフロー予測
  - 複数通貨対応
  - グローバル銀行連携
- **料金**: サブスクリプション型

### Goodbudget

- **URL**: https://goodbudget.com/
- **概要**: 封筒式予算管理アプリ
- **CSV対応**: あり
- **主な機能**
  - 封筒式予算管理
  - 家族シェア機能
  - グラフ分析
- **料金**: 無料版・プレミアム版

---

## 機能比較まとめ

| 機能 | 国内大手 | 海外大手 | 個人開発系 |
|---|---|---|---|
| CSV取り込み | ◎ | ◎ | ◎ |
| 自動カテゴリ分類 | ◎ | ◎ | △ |
| グラフ表示 | ◎ | ◎ | ○ |
| 予算管理 | ○ | ◎ | △ |
| API連携 | ◎（大手のみ） | ○ | △ |
| 開発者API | △ | ○（Lunch Money等） | △ |

---

## KakeMieru への示唆

### MVPとして最低限必要なもの
- CSVアップロード（カード会社ごとのフォーマット差異への対応）
- カテゴリ自動分類（キーワードマッチで十分）
- グラフ表示（月別・カテゴリ別）

### 差別化できる可能性があるもの
- 日本のカード会社CSVフォーマットへの特化対応（Shift-JIS対応含む）
- 分割払いの自動検知
- ポートフォリオとしてのコードの透明性（OSSとして公開）

### スクレイピングAPIについて
個人開発レベルでは現実的でない。CSVアップロードを軸に設計する。

---

## 参考ソース

- [マネーフォワード 金融機関とのAPI契約状況（2020年）](https://corp.moneyforward.com/news/release/service/20200617-mf-press/)
- [Zaim 利用規約・API連携について](https://content.zaim.net/legal/api)
- [Zaim 100万ユーザー突破インタビュー（2013年）](https://thebridge.jp/2013/10/zaim-takako-kansai)
- [Lunch Money - Import Transactions](https://lunchmoney.app/features/import-transactions/)
- [YNAB - File-Based Import Guide](https://support.ynab.com/en_us/file-based-import-a-guide-Bkj4Sszyo)
- [YNAB - Formatting a CSV File](https://support.ynab.com/en_us/formatting-a-csv-file-an-overview-BJvczkuRq)
- [Actual Budget 公式サイト](https://actualbudget.org/)
- [Firefly III 公式サイト](https://www.firefly-iii.org/)
- [Goodbudget - How to Import CSV Files](https://goodbudget.com/help/using-accounts/how-to-import-csv/)
- [Monarch Money - Import Transaction Data](https://help.monarchmoney.com/hc/en-us/articles/4409682789908)
- [PocketSmith - Global Personal Finance Software](https://www.pocketsmith.com/global-personal-finance-software/)
- [Koody - Personal Finance App With CSV Import](https://koody.com/blog/personal-finance-app-csv-import)
- [Empower Personal Dashboard Support](https://support-personalwealth.empower.com/)
