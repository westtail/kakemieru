# ADR-0020: 画面設計方針（入力経路・編集モードの分離・技術方針）

- 日付: 2026-04-11
- ステータス: 決定済み

---

## コンテキスト

以下の観点で画面設計の方針を決定する必要があった。

1. データの入力経路（CSV・手動1件・手動まとめ）をどの画面で受けるか
2. 関連する操作を同じ画面に統合するか分けるか
3. まとめて手動入力した場合を Import として扱うか
4. JS の使いどころをどこに限定するか

---

## 決定事項

### 1. 手動まとめ入力は Import として扱う

複数件の手動入力（現金払いなどをまとめて記録する操作）は `source_type: manual_bulk` の Import レコードを作成する。

**理由**
- 「この3件をまとめてやり直す」という操作が自然にできる
- CSV 取り込みと同じ Import の仕組みに乗れる
- Transaction の `import_id = NULL` = 手動1件入力 の定義を維持できる

```text
入力経路と Import の対応
  CSV 取り込み    → Import（source_type: csv）         + Transaction N件
  手動まとめ入力  → Import（source_type: manual_bulk）  + Transaction N件
  手動1件入力     → Transaction 1件のみ（import_id = NULL）
```

### 2. 全画面を機能単位で分離する

関連する操作を1画面に統合するか分けるかを検討し、全て分離する方針にした。

| 統合案 | 分離案（採用） | 採用理由 |
|---|---|---|
| インポート + 履歴を1画面 | `/imports/new` + `/imports` に分離 | 将来の入力経路増加に対応しやすい |
| 明細一覧 + 編集をモーダル | `/transactions` + `/transactions/:id/edit` に分離 | 編集項目の増加に余裕がある |
| 予算表示 + 予算設定を1画面 | `/budgets/:ym` + `/budget_templates` に分離 | テンプレートの複数管理に対応しやすい |

### 3. 「取り込む」ボタンは複数箇所に配置する

取り込み操作は `/imports/new` に集約するが、アクセス導線を複数用意する。

```text
ダッシュボード  → [CSV取り込み] ボタン
明細一覧        → [CSV取り込み] ボタン（データがない月は特に目立つ）
グローバルナビ  → [+ 取り込み] 常設
```

**理由**: 「アプリを開く → 明細を見る → まだ取り込んでいない」という導線が自然に発生するため。

### 4. 明細編集で変更できる項目を限定する

CSV 原本（`date` / `amount` / `description`）は変更不可。編集できるのは以下のみ。

| カラム | 編集内容 |
|---|---|
| `merchant_name` | 店舗名の正規化・修正 |
| `category_id` | カテゴリの変更 |
| `amount_override` | 金額の訂正（NULL = 原本を使用） |
| `date_override` | 日付の訂正（NULL = 原本を使用） |
| `deleted_at` | ソフトデリート（明細の削除） |

### 5. フロントエンド技術方針

Rails 8 + Hotwire（Turbo + Stimulus）を基本とし、JS は最小限に限定する。

| 操作 | 実装方法 | 理由 |
|---|---|---|
| カテゴリ変更・明細削除・金額訂正 | Turbo Stream | JS不要・サーバーレンダリングで部分更新 |
| フォーム送信・ページ遷移 | Turbo Drive | 通常の Rails フォーム |
| 手動まとめ入力の行追加 | Stimulus | DOM 操作が必要な最小限の JS |
| グラフ描画・月切り替え | Stimulus + fetch + Chart.js | JSON を受け取って再描画 |

**Turbo Stream の位置づけ**

JSON を返す API エンドポイントとは異なり、HTML を返すことで部分更新を実現する。JS をほぼ書かずに「ページ遷移なし・即時反映」という API 的な UX を得られる。

```text
カテゴリ変更の流れ
  セレクト変更
  → POST /transactions/:id
  → Turbo Stream（HTML を返す）
  → 該当行だけ書き換わる・ページ遷移なし
```

グラフデータのみ JSON エンドポイント（`GET /transactions/summary?month=YYYY-MM`）を用意し、Stimulus から fetch して Chart.js に渡す。

### 6. 認証・退会フロー

| 画面 | 内容 |
|---|---|
| `/sign_up` | 登録完了時に「現金」PaymentMethod と初期カテゴリを自動生成 |
| `/sign_in` | メール + パスワード認証（Rails 8 Built-in） |
| `/password/reset` | パスワードリセットメール送信 |
| `/password/edit` | パスワード再設定 |
| `/account/delete` | 退会確認。確認文字列の入力を要求（誤操作防止）。実行で users を CASCADE 削除 |

---

## 保留事項

- 手動まとめ入力の行数上限（何件まで一度に入力できるか）
- Import 取り消し時の確認フロー（件数が多い場合の警告表示）
- 手動1件入力と手動まとめ入力の導線の統一方法
- ダッシュボードのグラフ詳細設計（表示期間・集計単位）
- 予算ページの詳細設計（フェーズ2）

---

## 結果

詳細な画面設計は [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md) を参照。
