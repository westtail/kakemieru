import { Controller } from "@hotwired/stimulus"

// 手動まとめ入力のテーブルで行の追加・削除を行う。
// 行数が max に達したら「行を追加」ボタンを無効化する。
export default class extends Controller {
  static targets = ["list", "template", "addButton"]
  static values = { max: Number }

  connect() {
    this.updateAddButton()
  }

  addRow() {
    if (this.atMax) return
    this.listTarget.appendChild(this.templateTarget.content.cloneNode(true))
    this.updateAddButton()
  }

  removeRow(event) {
    const row = event.target.closest(".manual-row")
    if (row) row.remove()
    this.updateAddButton()
  }

  updateAddButton() {
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = this.atMax
  }

  get atMax() {
    return this.maxValue > 0 && this.rowCount >= this.maxValue
  }

  get rowCount() {
    return this.listTarget.querySelectorAll(".manual-row").length
  }
}
