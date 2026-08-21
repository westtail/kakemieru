# ADR-0039: S4 支払方法の削除・アーカイブ Turbo Stream 化

- 日付: 2026-08-21
- ステータス: 承認（スコープ確定）
- 関連: [ADR-0025 支払方法](0025-s4-payment-method-plan.md) / #44 明細の Turbo Stream 化（transactions）
- 対象 Issue: #53 と同 S、直接は **#26**

---

## コンテキスト

支払方法の削除/アーカイブの分岐ロジック（`archivable?` 判定 → 明細/取り込み履歴があれば `archive!`、無ければ物理削除、`with_lock` で原子的）は #21 で既に実装済み。ただしレスポンスは全画面リダイレクトで、一覧もアクティブ分のみ表示。

#26 の主眼は **UX の Turbo Stream 化**:

- 明細ゼロ: ワンクリック確認 → 物理削除 → 行を Turbo Stream で除去
- 明細あり: 「N 件の明細があるためアーカイブします」と説明して確認 → `archived_at` 設定 → 行をアクティブから除去しアーカイブ済みセクションへ移動

---

## 論点と決定

- **`destroy` を Turbo Stream 応答に**: 成功時は `destroy.turbo_stream.erb` を描画する。
  - 物理削除: `turbo_stream.remove(@payment_method)`。
  - アーカイブ: アクティブ行を `remove` し、アーカイブ済みコンテナへ `append`。`@archived` フラグで分岐。
  - 非 Turbo（`format.html`）は従来どおり `redirect_to` + flash（Turbo もリダイレクトを追従するため後方互換）。
- **現金ガード / 所有権**: 現金は早期 `redirect_to`（alert）で維持（UI にボタンを出さない防御網）。他ユーザーは `set_payment_method` の所有スコープで 404。いずれも Turbo でもリダイレクト追従で破綻しない。
- **一覧は 2 セクション**: アクティブ（`active`）とアーカイブ済み（`archived`）を別リストで描画。アーカイブ済みコンテナ `ul#archived-payment-methods` は空でも常に描画し、`append` の対象を保証する。
- **確認 UX は `turbo_confirm`**: 行の削除/アーカイブボタンに、描画時に決めた分岐文言を `data-turbo-confirm` で渡す。Turbo ネイティブのダイアログで JS を増やさず、既存の削除確認と一貫。文言は明細件数 N を含める。
- **確認文言の分岐（描画時）**: サーバ側の `archivable?` と対応させる。
  - 明細あり: 「この支払方法には N 件の明細があります。削除せずアーカイブします。」
  - 取り込み履歴のみ: 「取り込み履歴があるため、削除せずアーカイブします。」
  - 履歴なし: 「「name」を削除します。」
  ヘルパー `payment_method_removal_confirm` に集約。
- **N+1 回避**: 一覧描画で各行が件数を都度問い合わせないよう、`transactions` 件数を `group(:payment_method_id).count` の集約1本、取り込み保有は `payment_method_id` の集合を1本で先読みする。
- **アーカイブ済み行は表示のみ**: 復元（unarchive）や再削除は #26 の範囲外（YAGNI）。バッジ表示のみ。

---

## 実装

- `app/controllers/payment_methods_controller.rb`: `index` に `active`/`archived` と件数先読みを追加。`destroy` を `respond_to`（turbo_stream / html）に変更し `@archived` を設定。
- `app/views/payment_methods/index.html.erb`: 2 セクション化。行 partial を利用。Tailwind は最小限（本格刷新は #52）。
- `app/views/payment_methods/_payment_method.html.erb`（新規）: アクティブ行。`dom_id` 付与、編集リンク、削除/アーカイブボタン（`turbo_confirm`）。
- `app/views/payment_methods/_archived_payment_method.html.erb`（新規）: アーカイブ済み行。`dom_id` 付与、バッジ表示のみ。
- `app/views/payment_methods/destroy.turbo_stream.erb`（新規）: remove（＋アーカイブ時 append）。
- `app/helpers/payment_methods_helper.rb`（新規）: `payment_method_removal_confirm`。

## テスト

- `spec/requests/payment_methods_spec.rb`（更新）:
  - 履歴なし → 物理削除され、Turbo Stream で `remove` される（`as: :turbo_stream`、media_type と body を検証）。
  - 明細あり → `archived_at` 設定、Turbo Stream で active から remove ＋ archived コンテナへ append。
  - 取り込み履歴のみ → 同様にアーカイブ。
  - 現金ガード・所有権 404 は従来どおり（リダイレクト/404）。
  - 一覧にアーカイブ済みセクションが出る（`archived` の名前が表示される）。

## スコープ外

- アーカイブ済みの復元（unarchive）、アーカイブ済みの再削除。
- カスタムモーダル UI・支払方法一覧の本格デザイン刷新（#52 FE 横断）。
