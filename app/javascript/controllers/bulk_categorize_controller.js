import { Controller } from "@hotwired/stimulus"

// 明細一覧のカテゴリ一括適用の選択 UI（#149）。
// - all: 全選択チェックボックス（ヘッダー）
// - row: 各行の選択チェックボックス
// - apply: 一括適用ボタン（1件以上選択で有効化）
// - count: 選択件数の表示
export default class extends Controller {
  static targets = ["all", "row", "apply", "count"]

  connect() {
    this.refresh()
  }

  // インライン変更で行が Turbo Stream 差し替えされた後も件数・活性を同期し直す。
  rowTargetConnected() {
    this.refresh()
  }

  // ヘッダーの全選択で全行を切り替える。
  toggleAll() {
    this.rowTargets.forEach((cb) => { cb.checked = this.allTarget.checked })
    this.refresh()
  }

  // 選択件数を数え、適用ボタンの有効/無効と全選択の状態を同期する。
  refresh() {
    const selected = this.rowTargets.filter((cb) => cb.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = selected
    if (this.hasApplyTarget) this.applyTarget.disabled = selected === 0

    if (this.hasAllTarget) {
      const total = this.rowTargets.length
      this.allTarget.checked = total > 0 && selected === total
      this.allTarget.indeterminate = selected > 0 && selected < total
    }
  }
}
