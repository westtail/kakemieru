# ADR-0007: データベース選定

- 日付: 2026-03-22
- ステータス: 決定済み

---

## コンテキスト

家計簿アプリとして、ユーザー・カード・明細・カテゴリ・予算など複数エンティティ間の関係を管理する必要がある。
データベースの種類（RDB vs NoSQL）と製品（PostgreSQL vs MySQL）を決定する。

---

## 検討した選択肢

### RDB vs NoSQL

| | RDB | NoSQL（MongoDB等） |
|---|---|---|
| **向いているデータ** | 関係データ・集計・結合 | 非構造データ・大量書き込み |
| **このアプリへの適合** | ◎ 明細・予算・カテゴリは関係データ | △ RDBで十分な規模 |
| **トランザクション** | ◎ ACID保証 | △ 製品依存 |
| **集計・分析** | ◎ SQL集計が強力 | △ 集計クエリが複雑 |

**結論**: 関係データが中心でSQLの集計が活きるためRDBを採用。

---

### PostgreSQL vs MySQL

| | PostgreSQL | MySQL |
|---|---|---|
| **JSON型** | ◎ ネイティブ対応 | △ 限定的 |
| **全文検索** | ◎ 標準搭載 | △ 別途設定 |
| **Fly.io対応** | ◎ Fly Postgres公式提供 | △ 自前構築が必要 |
| **Rails標準** | ◎ `--database=postgresql` | ◯ 対応済み |
| **採用実績** | ◎ Web系スタートアップで主流 | ◎ 国内企業（楽天・DeNA等）で主流 |
| **将来のGCP移行** | ◎ Cloud SQL PostgreSQL | ◯ Cloud SQL MySQL |

---

## 決定事項

### PostgreSQL を採用する

**理由**:
- 明細・予算・カテゴリなど関係データが中心でRDBが最適
- **Fly.io が Fly Postgres を公式提供しており追加設定不要**（主な決め手）
- MySQLも十分な選択肢だが、Fly.ioとの統合コストでPostgreSQLが有利
- GCP移行時も Cloud SQL PostgreSQL で継続利用可能

**将来的な拡張可能性**:
- カテゴリキーワードのJSON管理（JSON型）
- 明細の全文検索（pg_search gem）
- 分析クエリのパフォーマンス向上（インデックス設計）

---

## ログ・監視方針

Fly.ioのログ機能を活用する：

| 方法 | 用途 |
|---|---|
| `fly logs` | CLIでのリアルタイムログ確認 |
| RailsログをSTDOUT出力 | Fly.ioが自動収集 |
| Log Drains（任意） | 将来的にPapertrail等へ転送 |

nginxは不要。Rails 8内蔵の**Thruster**が圧縮・アセットキャッシュ・HTTP/2をカバーする。

---

## MySQLが有力になるケース（参考）

今回は不採用だが、以下の構成ではMySQLが有力な選択肢になる：

| 構成 | 理由 |
|---|---|
| **AWS RDS / Aurora MySQL** | 日本のAWS案件はAurora MySQLが鉄板。業務での採用実績が多い |
| **PlanetScale** | MySQL互換のサーバーレスDB。スケール性能が高い |
| **さくらDB等の国内サービス** | MySQL指定が多い |

AWS案件を意識したポートフォリオを作るなら、意図的にMySQLを選ぶ戦略もある。

---

## 結果

[docs/PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md) の技術スタックに反映済み。
