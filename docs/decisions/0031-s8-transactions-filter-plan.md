# ADR-0031: S8 明細一覧・絞り込みバーの実装計画

- 日付: 2026-08-16
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0027 S7明細](0027-s7-transactions-plan.md) / [SCREEN_DESIGN.md](../design/SCREEN_DESIGN.md)（絞り込みバー・未分類ディープリンク）
- 対象 Issue: #43（明細一覧・絞り込みバー）

---

## コンテキスト

現在の `/transactions` は月別の素なリスト表示のみ。S8 の入口として、月・カテゴリ・キーワードで絞り込める一覧画面にする。これが明細編集（#41）・カテゴリ即時変更 Turbo Stream（#44）・ダッシュボード（#48）の土台になる。

**スコープ**: 今回は一覧＋絞り込みに集中。テーブルのカテゴリは表示のみ、操作ボタンは置かない（編集/削除は #41、カテゴリ即時変更セレクトは #44 で配線）。リンク切れを作らない。

---

## 論点と決定

- **カテゴリ絞り込みの値規約**（SCREEN_DESIGN 準拠・#48 のディープリンク互換）:
  - `category` 無し（初回）または `"all"` → すべて（絞り込みなし）
  - `category=""`（空文字）→ 未分類（`category_id IS NULL`）
  - `category="<id>"` → そのカテゴリ。`Current.user.transactions` スコープ下なので他人の id を渡しても 0 件で安全（情報漏れなし）。
- **月セレクト**: ユーザーの明細が存在する月（`effective_date` を月単位に丸めた distinct）＋当月＋表示中の月、降順。デフォルトは当月。値は `YYYY-MM`（既存 `parse_month` と一致）。
- **キーワード**: `merchant_name` の前方一致。パラメータ `q`。`LIKE` のワイルドカードは `sanitize_sql_like` でエスケープ。
- **未分類の強調**: 該当行を淡い背景で強調し「未分類」ラベルを表示。
- **N+1**: 既存の `includes(:category, :payment_method)` を維持。

---

## 実装

- **Transaction**: `merchant_prefix` スコープ追加（前方一致・エスケープ）。カテゴリ絞り込みは controller で `where(category_id:)` / `where(category_id: nil)`。
- **TransactionsController#index**: `@category` / `@keyword` / `@categories` / `@month_options` を用意し、既存の月内スコープにカテゴリ・キーワードを合成。`apply_category_filter` を private に。
- **views/transactions/index**: 絞り込みバー（GET フォーム: 月/カテゴリ/キーワード）＋テーブル（日付・店舗名・金額・カテゴリ・支払方法）＋未分類強調＋該当なしメッセージ。Tailwind で整形。

---

## スコープ外（後続）

- 明細編集・削除（#41）、カテゴリ即時変更 Turbo Stream（#44）。
- 合計・サマリー（#45）、ページネーション、日付範囲の絞り込み。
