import { Controller } from "@hotwired/stimulus"

// 明細一覧のカテゴリ一括適用の選択 UI。
// - all: 全選択チェックボックス（ヘッダー）
// - row: 各行の選択チェックボックス
// - apply: 一括適用ボタン（1件以上選択で有効化）
// - count: 選択件数の表示
//
// 選択 ID は Set（this.selected）で「選択の意図」を保持し、更新はユーザー操作（toggle）
// のときだけ行う。件数・活性は常にライブ DOM のチェック状態から計算する。
// インライン変更で行が Turbo Stream 差し替えされると未チェックで再生成されるため、
// rowTargetConnected で Set に基づきチェックを復元する（集合は書き換えない）。
// 行削除（rowTargetDisconnected）でも件数を再計算する。
export default class extends Controller {
  static targets = ["all", "row", "apply", "count"]

  connect() {
    this.selected = new Set()
    this.updateUi()
  }

  // 行チェックの変更（ユーザー操作）。このときだけ選択集合を更新する。
  toggle(event) {
    const cb = event.target
    if (cb.checked) this.selected.add(cb.value)
    else this.selected.delete(cb.value)
    this.updateUi()
  }

  // ヘッダーの全選択で全行を切り替える。
  toggleAll() {
    this.rowTargets.forEach((cb) => {
      cb.checked = this.allTarget.checked
      if (cb.checked) this.selected.add(cb.value)
      else this.selected.delete(cb.value)
    })
    this.updateUi()
  }

  // 差し替えで再生成された行は選択集合に基づきチェックを復元する（集合は変更しない）。
  rowTargetConnected(checkbox) {
    if (this.selected && this.selected.has(checkbox.value)) checkbox.checked = true
    this.updateUi()
  }

  // 行削除後も件数・活性を再計算する。
  rowTargetDisconnected() {
    this.updateUi()
  }

  // 件数・ボタン活性・全選択の状態をライブ DOM から同期する。
  updateUi() {
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
