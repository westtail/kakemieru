# ADR-0025: S4 支払方法機能の実装計画

- 日付: 2026-08-11
- ステータス: 承認（2026-08-11 スコープA・論点確定）
- 関連: [ADR-0019 取り込み・支払方法設計](0019-import-and-payment-method-design.md) / [ADR-0024 S3 カテゴリ計画](0024-s3-categories-plan.md) / [ADR-0013 DBモデル設計](0013-database-model-design.md)
- 対象 Issue: #28 / #30 / #27 /（#21 の現金自動生成の残り）

---

## コンテキスト

フェーズ1の実装単位 S4「支払方法（payment_methods）」。CSV 取り込み（S5-6）や明細（S7）が `payment_method_id` を必須参照するための土台。あわせて登録時の「現金」自動生成を実装し **#21 を完結**させる（カテゴリコピーは S3 で実装済み）。

| Issue | 内容 |
|---|---|
| #28 | [migration] payment_methods テーブル |
| #30 | PaymentMethod モデル + spec |
| #27 | 支払方法管理画面 CRUD + spec |
| #21 | 登録時に payment_type:cash の「現金」を自動生成（残り） |

**スコープ（決定・A）**: 基本 CRUD のみ。S3 カテゴリと同型で最小に積む。アーカイブ/復元・Turbo Stream(#26) は後回し（後述）。

---

## テーブル設計（決定）

| カラム | 型 | 制約 |
|---|---|---|
| id | bigint | PK |
| user_id | bigint | NOT NULL / FK → users |
| name | string | NOT NULL |
| payment_type | string | NOT NULL / CHECK(5値) |
| archived_at | datetime | nullable（NULL = 使用中） |
| timestamps | | |

**インデックス**
- `UNIQUE(user_id, name)` … 同一ユーザー内の名前重複を禁止
- `UNIQUE(user_id, id)` … **S7 transactions の複合FK `(user_id, payment_method_id)` の参照先**。categories と同様に先行付与
- `(user_id, archived_at)` … S7 のアクティブ絞り込み用（Issue #28 準拠。DATABASE_DESIGN の archived_at 単独から拡張）

**CHECK 制約**: `payment_type IN ('credit','debit','e_money','qr','cash')`。値はマイグレーションにインライン（履歴を不変にする。ADR-0024/レビューの教訓）。

**payment_type（Rails enum + CHECK）**: credit / debit / e_money / qr / cash。アプリ初の enum 導入。値は `config/constants/payment_methods.rb`（`PaymentMethodCatalog`）に一元化。

---

## 論点と決定

### 1. transactions 依存部分は S7 へ繰り延べ（決定）

ADR-0024 決定#1（存在するモデルの関連のみ宣言）と同じ方針。transactions テーブルは S7 で作られるため、S4 では以下を実装・検証できない。

- **削除ポリシーのアーカイブ分岐**（明細あり→`archived_at` セット）と `before_destroy`（`transactions.exists?` 依存）→ **S7**。S4 の削除は常に物理削除（明細が存在しないため）。
- **アーカイブ/復元 UI・アクティブ/アーカイブ分離表示（#27 の一部）・Turbo Stream(#26)** → **S7**。archive はトランザクション（明細）が生じて初めて意味を持つため、今作ると実質空の UI になる。
- `has_many :transactions`（S7）/ `has_many :imports`（S5）→ 各スライスで追加。

`archived_at` カラムと `active/archived` スコープは**先行して用意**する（後付けマイグレーションを避ける）。S4 では全件アクティブ。

### 2. 現金の削除ガード（決定）

「現金」は登録時に自動生成され、**削除不可**（SCREEN_DESIGN）。初期カテゴリの削除拒否と同型で、`payment_type == "cash"` を判定して `destroy` を拒否する（UI に削除ボタンを出さず、直接リクエストも拒否）。名前変更は可。

### 3. cash はフォームの選択肢に出さない（決定）

作成フォームの payment_type セレクトは `SELECTABLE_TYPES = [credit, debit, e_money, qr]` のみ。現金は登録時に1件だけ自動生成される特別枠で、ユーザーが追加作成する必要がないため。これにより「削除不可の cash が複数できる」事態も防ぐ。

### 4. 登録時の現金自動生成で #21 完結（決定）

ADR-0019 決定#3（案Y）に従い、登録成功時に `PaymentMethod.create_default_for(user)`（`name:"現金", payment_type:"cash"`）を1件生成。S3 のカテゴリコピーと同じトランザクション内で原子的に行う。

---

## テスト方針（TDD: RED → GREEN → REFACTOR）

### #28 マイグレーション
- migrate / rollback / redo / schema.rb（3インデックス・CHECK 制約）確認

### #30 モデル spec（`spec/models/payment_method_spec.rb`）
| 観点 | ケース |
|---|---|
| 関連 | belong_to(:user)（Shoulda） |
| バリデーション | name / payment_type 必須（Shoulda）。name の user スコープ一意（**明示テスト**＝FK で shoulda 誤検知） |
| enum | payment_type の 5 値・`cash?` |
| スコープ | active（archived_at NULL）/ archived |
| 既定生成 | `create_default_for` で現金1件（name/type 一致） |

### #27 リクエスト spec（`spec/requests/payment_methods_spec.rb`）
未ログイン→/sign_in / 追加・名前変更・削除 / **現金は削除拒否** / 他ユーザーは 404 かつ不変 / 名前重複 422。

### 登録フロー（#21）
`registrations_spec.rb` に「登録で現金が1件生成される」を追加。

---

## 実装順序

```text
1. config/constants/payment_methods.rb + application.rb require
2. #28 migration（テーブル+3インデックス+CHECK）→ 可逆性・schema 確認
3. #30 モデル spec(RED) → PaymentMethod + User 関連 + create_default_for(GREEN)
4. 登録フローに現金生成を配線 + registrations_spec(GREEN)
5. #27 request spec(RED) → PaymentMethodsController + ビュー + routes(GREEN)
6. 全スイート + rubocop + brakeman → ruby/security レビュー → 分割コミット → PR
```

---

## スコープ外（S4 では扱わない）

- アーカイブ/復元・Turbo Stream(#26)・before_destroy のアーカイブ分岐 → **S7**
- `has_many :transactions`（S7）/ `has_many :imports`（S5）
- #29 デプロイ（S3-S4 実機確認）は S4 マージ後に別途

---

## 参考

- [ADR-0019 取り込み・支払方法設計](0019-import-and-payment-method-design.md)
- [DATABASE_DESIGN.md](../design/DATABASE_DESIGN.md)（payment_methods 定義・削除ポリシー）
- [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md)（支払方法一覧・現金の扱い）
