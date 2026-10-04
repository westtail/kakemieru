# デザインシステム「家計簿ノート」

最終更新: 2026-10-04

ビジュアル指針「家計簿ノート」のトークンとコンポーネント定義。採用の意思決定は [ADR-0050](../decisions/0050-design-system.md)、クラス体系の土台は [ADR-0043](../decisions/0043-ui-component-classes-plan.md) を参照。

実装は Tailwind CSS v4（standalone・importmap構成）。トークンは CSS カスタムプロパティで定義し、コンポーネントは `app/assets/tailwind/application.css` の `@layer components` で組む（既存方針の踏襲）。

---

## 1. コンセプト

- **温かみ（紙）× 信頼（インクと数字）× 親しみ（余白と丸み）**。
- 題材は「クレジットカード明細 → 家計簿」。手元の帳簿／レシートの比喩で、金額は等幅で几帳面に、要所に朱印のアクセント。
- 一次アクションはインク紺、朱は「印・下線・強調・アイコン」に限定して効かせる（朱を多用しない）。
- 背景は紙の地色のみ。**方眼（網目）は使わない**（可読性優先）。

---

## 2. デザイントークン

CSS 変数として定義する（ライトを既定とし、ダークは role を入れ替えて再定義。全画面のダーク適用は段階的）。

### カラー（ライト）

| トークン | 値 | 用途 |
|---|---|---|
| `--paper` | `#f7f4ec` | ページ地色（紙） |
| `--paper-2` | `#efeadd` | セクションのトーン帯・淡い面 |
| `--ink` | `#202b45` | 本文・見出し・一次ボタン地 |
| `--ink-2` | `#4a5680` | 補助テキスト・キャプション |
| `--stamp` | `#c23b2b` | ブランドアクセント（朱）: 印・下線・強調 |
| `--stamp-bg` | `#f8ece7` | 朱の淡い背景（チップ・バッジ・アイコン台） |
| `--line` | `#e7e1d2` | 罫線・カード境界（控えめ） |
| `--card` | `#ffffff` | カード地 |
| `--teal` | `#2f6d8a` | 藍（ステップ3・カテゴリ「藍鉄」と同系） |
| `--bar-bg` | `#ddd6c6` | 棒グラフの非強調バー |

### セマンティックカラー（アクセントとは別系統）

CSS 変数名は `--ok`（positive/notice）／`--alert`／`--warn`。淡背景ペアは §7.2 を参照。

| 役割 | 変数 | 値 | 用途 |
|---|---|---|---|
| positive / notice | `--ok` | `#2f7a55` | 成功フラッシュ・減少（良い方向） |
| alert / 重要 | `--alert` | `#c23b2b` | エラーフラッシュ・未分類の警告（朱と同系で可） |
| warning | `--warn` | `#d8a23a` | 注意・保留。**紙上 ~2:1 でテキスト不可**→面・枠・バッジのみ |
| 支出増（使いすぎ） | — | `#c23b2b` | 前月/平均比のプラスなど |
| 支出減 | — | `#2f7a55` | 前月/平均比のマイナスなど |

### グラフのカテゴリ配色（ドーナツ標準）

白カード上で判別しやすい、ブランドに馴染む彩度抑えめの12色。先頭から循環。**「その他」は末尾の鈍色に固定**し、**棒グラフの当月は `--stamp`** で強調する。

```text
1  #c23b2b  朱      （食費など先頭カテゴリ）
2  #2f6d8a  藍鉄
3  #d8a23a  山吹
4  #4b8f6e  緑青
5  #9c5fb0  古代紫
6  #d9774e  洗朱
7  #3f7cc0  縹
8  #7a8b4f  olive
9  #c06597  梅
10 #5aa0a0  青竹
11 #8a6d53  茶
--  #6b7794  鈍色（「その他」固定）
```

実装: `app/javascript/controllers/dashboard_controller.js` の `CATEGORY_COLORS` を上記へ差し替える（現状は青/橙系の汎用配色）。

### タイポグラフィ

| 役割 | フォント | 補足 |
|---|---|---|
| 見出し・本文 | `"Zen Kaku Gothic New"` | 400 / 500 / 700 / 900。Google Fonts |
| 数字（金額・日付） | `"Roboto Mono"` | `font-variant-numeric: tabular-nums` で桁揃え |
| フォールバック | `system-ui, -apple-system, "Hiragino Kaku Gothic ProN", "Noto Sans JP", sans-serif` | |

**丸ゴシックは採用しない**（ADR-0050）。金額・件数・日付など数字が並ぶ箇所は等幅＋tabular-nums を徹底。

タイプスケール（目安 / レスポンシブは `clamp()`）:

| 用途 | サイズ | 太さ |
|---|---|---|
| ヒーロー h1 | 30–54px | 900 |
| セクション見出し h2 | 21–28px | 900 |
| カード見出し h3 | 16–17px | 700–800 |
| 本文 | 14–17px / 行間1.9 | 400 |
| キャプション | 12–13px | 400–700 |
| ラベル（eyebrow） | 11–12px / letter-spacing .2em | 800・朱 |

### 余白・角丸・影・境界

| トークン | 値 | 用途 |
|---|---|---|
| radius-sm | 8px | 小要素・バッジ |
| radius-md | 11–13px | ボタン・アイコン台 |
| radius-lg | 16–18px | カード |
| radius-pill | 999px | チップ・ステップ円 |
| shadow-card | `0 6px 18px rgba(32,43,69,.06)` | 通常カード |
| shadow-elevated | `0 16px 36px rgba(32,43,69,.14)` | ミニダッシュボード等の主役 |
| border | `1px var(--line)` / 強調は `1.5–2px var(--ink)` | カード境界 |
| 読み幅 | 本文 `max-width: 34em`（約65字） | リード文 |
| セクション余白 | `clamp(26px, 5.5vw, 60px)` | pad |

---

## 3. コンポーネント

既存の `@layer components`（`.btn-primary` 等）を本指針の配色・形に更新し、新規コンポーネントを追加する。

### ロゴ（虫眼鏡 × ¥）
ブランド名は **Kakemieru**（ローマ字）。ロゴマークは「家計（¥）を虫眼鏡で見る」を表す inline SVG（レンズの中に ¥、朱色）＝名前の由来（家計×見える）を図案化したもの。左にマーク＋「Kakemieru」。SVG のため解像度非依存（画像ファイル版の用意は非スコープ）。

### ボタン
| クラス | 見た目 | 用途 |
|---|---|---|
| `.btn-primary` | インク紺の塗り / 文字=紙色 / radius-md | 一次（登録・保存・送信） |
| `.btn-outline` | インクの枠線 / radius-md | 二次（ログイン・戻る） |
| `.btn-ghost` | 枠なし・`--ink-2` 文字 | 三次（控えめ） |
| `.btn-accent` | 朱の塗り（影つき） | 限定的な強調CTA（多用しない） |
| `.btn-danger` | 朱の枠線→hoverで塗り | 破壊的（削除） |

> 移行: 現行の青塗り `.btn-primary` をインク紺へ。青 (`bg-blue-600`) は廃し、強調は朱に寄せる。

### テキストリンク `.link`
既定は本文色、hover下線。強調リンクは朱。

### カード `.card`
白地・`1px --line`・radius-lg・shadow-card・内側 `padding: 24px`。見出し h3 ＋ 本文。

### ミニダッシュボード / レシート `.dashcard`
主役ビジュアル。白地・`1.5px --ink`・radius-lg・shadow-elevated。構成:
- 上段: 年月ラベル（`2026 / 04`）＋ 右に区分ラベル。
- 合計: 大きい金額（等幅）＋ チップ（例「直近3ヶ月平均比 +12.4%」）。
- グラフ: **カテゴリ別ドーナツ**（中央に合計・下に凡例＝カテゴリ名＋金額）。
- 破線区切り（`1.5px dashed --ink-2`）。
- 明細行 `.rrow`: 左にカテゴリ名（＋「自動」バッジ）、右に金額（等幅）。

### チップ / バッジ
| クラス | 用途 |
|---|---|
| `.chip` | 朱文字 × `--stamp-bg` × pill。指標（平均比など） |
| `.badge-auto` | 「自動」ラベル。自動分類済みを示す小バッジ（朱・小） |
| 未分類バッジ | 件数＋警告色（朱）。0件は positive 表現も可 |

### 機能アイコンタイル `.feat-ic`
48px・`2px --ink` 枠・radius-md・朱のラインアイコン（アップロード／タグ／グラフ等）。アイコンは inline SVG（絵文字は使わない）。

### ステップ円 `.step .n`
48px の円に等幅数字。順に `--ink` → `--stamp` → 藍（`#2f6d8a`）。見出し＋説明は中央寄せ。

### セクション見出し `.sect`
中央寄せ。eyebrow（朱・letter-spacing）＋ h2（900）。

### グローバルナビ（ログイン時）
紙色ヘッダー＋`--line` 下境界。`.nav-link`＝`--ink-2`、現在地 `.nav-link-active`＝朱背景＋朱文字（現状の青50/青700を朱系へ）。

### フラッシュ
`.flash-notice`＝positive（緑系）、`.flash-alert`＝alert（朱系）。紙地に馴染む淡い背景＋同系の枠。

---

## 4. レイアウト原則

- 紙の地色ベース、セクションは余白（`gap`）で分離。トーン帯が必要なら `--paper-2`。
- 見出しは中央寄せ、本文は読み幅 `max-width: 34em`。
- 金額・件数・日付は等幅＋`tabular-nums` で桁を揃える。
- レスポンシブ: 3カラムは狭幅で1カラムに折返し（目安 ~680px）、ヒーローの左右割りは ~760px で段組み。スマホ幅（~400px）で横スクロールを出さない。
- 影・枠・丸み・塗りは役割で使い分け、主役（ミニダッシュボード）だけを強い影で持ち上げる。

---

## 5. アクセシビリティ

- **コントラスト**: 本文は ink on 紙（≈6.5:1）で十分。ただし**朱（stamp #c23b2b）on 紙 ≈4.8:1** は通常テキストAA（4.5）ぎりぎりなので、朱は**太字・ラベル・アイコン・面**に限定し細字本文には使わない。**warn（#d8a23a）on 紙 ≈2:1 はテキスト不可**＝面・枠・バッジのみ。現在地ナビ `.nav-link-active`（朱 on stamp-bg ≈4.6:1）は余裕が無いため **bold 必須**。
- **フォーカス**: すべての操作要素（リンク・ボタン・入力）に共通の `:focus-visible` で朱リング（`outline: 2px solid var(--stamp); outline-offset: 2px`）。`.field-input` の `focus:outline-none` は**可視フォーカスに置換**する（outline を消したままにしない）。
- **モーション**: `prefers-reduced-motion` を尊重。共通コンポーネントの `transition-colors` も抑制対象に含める。
- **グラフ**: `role="img"` ＋ `aria-label`（例「カテゴリ別支出の円グラフ」）を付与。色だけに依存せず凡例に金額を併記。

---

## 6. 実装メモ（Tailwind v4）

- トークンは `app/assets/tailwind/application.css` 冒頭の `:root` に CSS 変数で定義。ダークは `:root[data-theme="dark"]` で再定義する（`@media (prefers-color-scheme: dark)` の自動発火は全画面移行が済むまで入れない。§7.2 参照）。
- コンポーネントは `@layer components` に展開（Tailwind v4 は `@apply` でのカスタムクラス合成が不可のため、各クラスにユーティリティを直接展開する／または `var(--token)` を直接指定）。
- Google Fonts は**公開 LP の landing レイアウトでのみ**読み込む（`referrerpolicy="no-referrer"` 付き）。認証後の家計データ画面から Google へ IP/Referer を送らないため、共通パーシャル `shared/_head_tags` には置かない。フォールバックスタックを必ず指定。全画面へフォントを広げる段階（§7 のアプリ全体適用PR）で、プライバシー/サプライチェーンの観点からセルフホスト化する（`body` へ本文フォントを適用するのと同一PRで供給を確定させる。さもないと認証後画面がフォールバックのみになる）。
- グラフは Chart.js（既存のダッシュボードで使用中）を流用。ドーナツ＝カテゴリ別、配色は本書 §2 のカテゴリ配色。

### 段階的移行

1. **LP（#172）**: 本指針で初適用（ヒーロー＝ドーナツ入りミニダッシュボード）。
2. **共通クラスの再配色**: `.btn-primary`/`.nav-link*`/`.link` を青→インク／朱へ。
3. **ダッシュボード配色**: `dashboard_controller.js` の `CATEGORY_COLORS` を §2 のカテゴリ配色へ。
4. 以降、カード・バッジ・フォーム等を順次本指針へ寄せる（破壊的変更を避け `@layer components` 経由で一括反映）。

---

## 7. アプリ全体への適用（次PR向けの実装仕様）

LP で確立した本指針を、既存の全画面へ段階的に広げるための具体仕様。LP の `.lp` スコープは残しつつ、トークンとベースを全体に昇格し、既存の共通コンポーネントクラス（`@layer components`）を再配色する。**挙動は変えない（見た目のみ）**。

### 7.1 適用方針

1. **トークンを `:root` に昇格**（現在は `.lp` スコープ）。LP も共通トークンを参照するよう置換（重複定義を解消）。
2. **ベースを `body` に適用**：背景 `var(--paper)`・文字 `var(--ink)`・本文フォント（Zen Kaku Gothic New）。※数字は該当箇所で `.num`（Roboto Mono + tabular-nums）を付与。
3. **既存の共通クラスを再配色**（§7.3）。クラス体系（ADR-0043）は維持し、青→インク/朱へ置換。
4. **新コンポーネントの共通化**：汎用的に使うもの（カード・バッジ・チップ等）は `lp-` 接頭辞を外した共通クラスへ昇格。LP 固有（ヒーロー・ミニダッシュボード・ロゴマーク）は `lp-` のまま。
5. **フォントのセルフホスト化**（全画面で読むため。プライバシー/パフォーマンス。§6 参照）。LP 限定の landing レイアウト読み込みは廃止し、`shared/_head_tags` へ戻す。**body へ本文フォントを適用する step2 と同一PRで供給（セルフホスト）を確定**させる（さもないと認証後画面がフォールバックのみに）。セルフホストなら将来 CSP を導入しても Google オリジンの allowlist 不要（self 完結）。

### 7.2 トークンの実体（`:root` 用・コピー可）

```css
:root {
  --paper:#f7f4ec; --paper-2:#efeadd; --ink:#202b45; --ink-2:#4a5680;
  --stamp:#c23b2b; --stamp-bg:#f8ece7; --line:#e7e1d2; --card:#ffffff; --teal:#2f6d8a; --bar-bg:#ddd6c6;
  /* セマンティック（status色）＋フラッシュ用の淡背景 */
  --ok:#2f7a55; --ok-bg:#e9f3ee; --alert:#c23b2b; --alert-bg:#fbece9; --warn:#d8a23a; --warn-bg:#f7eed8;
  color-scheme: light;
}
/* ダークは本PRでは自動発火させない（未移行画面が半ダークで崩れるため @media は入れない）。
   トークンのみ用意し data-theme="dark" トグル時に有効化。全画面のダーク対応は専用PRで @media を追加する。 */
:root[data-theme="dark"] {
  --paper:#15171c; --paper-2:#1c1f26; --ink:#ece7db; --ink-2:#a9a393;
  --stamp:#e0634f; --stamp-bg:#2a1b18; --line:#2c2f36; --card:#1b1e24; --teal:#5fa8c4; --bar-bg:#3a3d33;
  --ok:#5fb488; --ok-bg:#16241d; --alert:#e0634f; --alert-bg:#2a1b18; --warn:#e0b25a; --warn-bg:#2a2414;
  color-scheme: dark;
}
```

- **H1（重要）**: この PR では `@media (prefers-color-scheme: dark)` を**入れない**。入れると OS ダークのユーザーで body だけ反転し、未移行画面（素の `bg-white`/`text-gray-900`）が白地のまま残り判読不能になる。ダーク自動適用は全画面移行後の専用PRで。
- フラッシュのテキストは淡背景でも AA を満たす濃色を使う（例: notice=`#1f5a3e` / alert=`#8f2b22`）。`--*-bg`=背景、`--ok`/`--alert`=枠線・アイコン。`--ok/--alert/--warn` の status 値は §2 と一致。

### 7.3 既存コンポーネントクラスの移行マップ（目標値）

`@layer components`（`app/assets/tailwind/application.css`）を次へ置換する。Tailwind v4 は `@apply` でカスタムクラスを合成できないため、ユーティリティ直展開 or `var(--token)` 直書きで組む。

| クラス | 現状（青基調） | 目標（家計簿ノート） |
|---|---|---|
| `body` | 既定（system/白） | `background: var(--paper)` / 本文フォント / `color: var(--ink)` |
| `.page-title` | `text-gray-900` | `color: var(--ink)` |
| `.section-title` | `text-gray-700` | `color: var(--ink)` |
| `.muted` | `text-gray-500` | `color: var(--ink-2)` |
| `.btn-primary` | `bg-blue-600 text-white` | `background: var(--ink); color: var(--paper)`（インク塗り・`radius 11px`） |
| `.btn-secondary` | 塗り `bg-gray-100` | `border: 1.5px var(--ink); color: var(--ink)`（アウトライン）**※塗り→枠線は“見た目変更”。使用画面を洗い出し目視確認** |
| `.btn-danger` | red outline | 維持（`var(--alert)` にトークン化） |
| `.link` | `text-blue-600` | `color: var(--ink)` + hover下線／強調リンクは `var(--stamp)` |
| `.link-danger` | red | `var(--alert)` |
| `.nav-link` | `text-gray-600 hover:bg-gray-100` | `color: var(--ink-2)` / hover `--paper-2` |
| `.nav-link-active` | `bg-blue-50 text-blue-700` | `background: var(--stamp-bg); color: var(--stamp)` |
| `.flash-notice` | green-50/200/800 | `--ok` 系（薄背景＋同系枠＋濃文字） |
| `.flash-alert` | red-50/200/800 | `--alert` 系 |
| `.field-input` | `focus:border-blue-500` `focus:outline-none` | `focus:border var(--stamp)` ＋ **可視フォーカス（outline-none のままにしない）** |
| `.field-label` | `text-gray-700` | `color: var(--ink-2)` |
| `.flash`（基底） | `border` のみ（色未指定） | 枠色 `var(--line)`（notice/alert が上書き） |
| `.field` | 余白のみ | 変更なし（実害小） |

追加で昇格する共通コンポーネント（LP の `.lp-*` から汎用化）：`.card`、`.chip`、`.badge-auto`、`.feat-ic`（任意）。

**素のユーティリティ直書き画面の掃き出し（重要・H2）**: コンポーネントクラスを使わず Tailwind ユーティリティを直書きしている箇所は、上の再配色では変わらず**紙地の上にグレーのまま取り残される**。次を個別に対応する（トークンへ置換、または component クラス化）:
- `app/views/shared/_header.html.erb`（**全ページ常駐のグローバルナビ**）: `bg-gray-50 border-gray-200`、ロゴ `text-gray-900`、ドロップダウン `bg-white border-gray-200`、項目 `text-gray-700 hover:bg-gray-100`、ログアウト `text-gray-500`。→ 紙/インク/朱へ。ロゴマーク（¥虫眼鏡）は現状 LP 限定。アプリ側ヘッダーにも出すかは要判断。
- `app/views/layouts/application.html.erb` の `<main>`、`app/views/layouts/error.html.erb`（**独立レイアウト**・`.lp` 無し）の素クラス。
- `app/views/shared/_flash.html.erb` のユーティリティ。

### 7.4 スケール（具体値）

- **型**（`clamp()` 推奨）: h1 `1.75–3.375rem`/900 ／ h2 `1.3125–1.75rem`/900 ／ h3 `1.03–1.06rem`/700-800 ／ 本文 `0.875–1.0625rem`・行間1.9 ／ キャプション `0.75–0.8125rem` ／ ラベル `0.6875–0.75rem`・tracking .2em。
- **余白**（gap/padding の基準）: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 px。
- **角丸**: 8（小）/ 11（ボタン）/ 16–18（カード）/ 999（pill）。
- **影**: card `0 6px 18px rgba(32,43,69,.06)` ／ elevated `0 16px 36px rgba(32,43,69,.14)`。

### 7.5 画面別チェックリスト（移行スコープ）

機能ドメイン単位で「共通クラス差し替え → 画面確認」を回す。対象の主な要素:

- [ ] **認証**（sessions/registrations/passwords）: 見出し・フォーム（field-*）・btn-primary・link
- [ ] **アカウント**（accounts）: フォーム群・破壊的操作（退会=btn-danger）・設定トグル
- [ ] **カテゴリ**（categories ＋ 店舗ルールおすすめUI）: 一覧・カード・バッジ・btn
- [ ] **支払方法**（payment_methods）: 一覧2セクション・Turbo Stream 行・アーカイブ
- [ ] **特別ルール**（special_rules）: 多項目フォーム・一覧
- [ ] **取り込み**（imports ＋ タブ）: アップロード/手動タブ・履歴一覧・取消確認
- [ ] **明細**（transactions）: 一覧（表的レイアウト）・絞り込みバー・列ソート・インライン分類・一括適用
- [ ] **ダッシュボード**（home + Chart.js）: カード/数値（`.num`）・グラフ配色（§7.6）
- [ ] **エラー画面**（errors ＋ error レイアウト）: 404/422/500
- [ ] **横断**（shared/_header ナビ・flash・フッター・error レイアウト）

補足:
- **明細一覧の表的レイアウト**には LP に無い専用コンポーネントが要る（`.lp-rrow` は LP 専用）。行境界 `--line`・ヘッダ・zebra（必要なら `--paper-2`）等の**データ密集リスト用クラス**を §3 に追加する。
- **`body` の再配色はレイアウト非依存のグローバル `body {}` ルール**として置く（`.lp` スコープにしない）。そうすれば独立レイアウトの **error 画面**も紙地を継承する。
- **mailer / 印刷ビューは本スコープ外**（メールは外部フォント/CSS変数非対応）。明示的に対象外とする。

### 7.6 グラフ配色の反映（Chart.js）

`dashboard_controller.js` は **JS リテラルで色を持ち、CSS 変数を読めない**ため、下記の **hex を直接**記述する（現 `CATEGORY_COLORS` は10色→**12色へ拡張**）。

```js
// カテゴリ別（円/ドーナツ）。先頭から循環。
const CATEGORY_COLORS = [
  "#c23b2b", "#2f6d8a", "#d8a23a", "#4b8f6e", "#9c5fb0", "#d9774e",
  "#3f7cc0", "#7a8b4f", "#c06597", "#5aa0a0", "#8a6d53"
]
const OTHER_COLOR = "#6b7794" // 「その他」は末尾固定
// 月別推移（棒）: 当月＝#c23b2b（stamp）/ 非当月＝#ddd6c6（bar-bg）
```

- 「その他」末尾固定は**単純な配列差し替えでは実現しない**。未分類/「その他」カテゴリを検出して `OTHER_COLOR` を割り当てるロジックを `renderChart` に追加する。
- 棒グラフ（`renderTrend`）の現状ハードコード（当月 `#2563eb` / 非当月 `#93c5fd`）を上記へ置換。
- 凡例は金額併記（色依存回避・§5）。

### 7.7 受け入れ基準

- **DOM不変**: 既存の全 spec が緑。ただし request/model spec は**色やCSSを検証しない**ため、保証されるのは「DOM構造/テキスト/リンク先が不変」まで。
- **視覚回帰（必須ガードレール）**: spec 緑だけでは再配色の正しさ・崩れを担保できない。**機能ドメインごとに PC/スマホの目視（スクショ）**を行い、特に次を確認:
  - 全ページ常駐の**グローバルナビが紙/インク/朱に揃う**（H2 の取りこぼしが無い）。
  - **`.btn-secondary` の塗り→枠線化**で強調序列・レイアウトが崩れない（使用画面を列挙して確認）。
  - フラッシュ（notice/alert）が淡背景＋濃文字で **AA** を満たす。
- **コントラスト**: 本文 ink on 紙 AA 以上。朱は太字・ラベル・アイコン・面に限定、warn はテキスト不可、現在地ナビは bold（§5）。
- **フォーカス可視**: リンク/ボタン/入力に共通 `:focus-visible` 朱リング（`.field-input` の `outline-none` を残さない）。
- **モーション**: 共通コンポーネントの `transition-colors` も `prefers-reduced-motion` で抑制。
- **レスポンシブ**: スマホ幅で横スクロールを出さない。
- **ダーク**: トークンは用意するが `@media` 自動発火は入れない（全画面ダークは専用PR）。
- コミットは機能ドメイン単位で分割し、画面ごとにレビュー可能にする。

---

## 8. 参照

- [ADR-0050](../decisions/0050-design-system.md) デザイン指針の採用
- [ADR-0049](../decisions/0049-landing-page-plan.md) 公開ランディングページ
- [ADR-0043](../decisions/0043-ui-component-classes-plan.md) 共通UIコンポーネントクラス
- [SCREEN_DESIGN.md](SCREEN_DESIGN.md) 画面設計（技術方針）
- 比較検討のプレビュー（セッション内アーティファクト・ローカル）: 王道＋ドーナツを確定
