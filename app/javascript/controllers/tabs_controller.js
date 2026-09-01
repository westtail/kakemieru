import { Controller } from "@hotwired/stimulus"

// タブ切替。選んだパネルだけ表示し、他は隠す。
// - tab: クリックで切り替えるボタン（data-tab-name を持つ）
// - panel: 表示/非表示するパネル（data-tab-name を持つ）
// 初期タブは URL の hash（例 #manual-import）を優先。ナビの「CSV/手動」リンクは
// それぞれの hash を指すので、別ページからでも同ページ内リンクでも該当タブが開く
// （同ページ内はページ遷移せず hashchange だけ起きるため、その購読も行う）。
export default class extends Controller {
  static targets = ["tab", "panel"]
  // initial: hash が無いときの初期タブ（例: 手動入力の検証エラー再描画で "manual-import"）。
  static values = { initial: String }

  connect() {
    this.onHashChange = () => this.showFromHash()
    window.addEventListener("hashchange", this.onHashChange)
    this.showInitial()
  }

  disconnect() {
    window.removeEventListener("hashchange", this.onHashChange)
  }

  // タブクリック: hash を書き換え、hashchange 経由で表示を切り替える。
  select(event) {
    window.location.hash = event.currentTarget.dataset.tabName
  }

  // 初期表示: URL の hash を最優先。無ければサーバ指定の initial、それも無ければ先頭タブ。
  showInitial() {
    const names = this.tabNames()
    const fromHash = window.location.hash.replace(/^#/, "")
    if (names.includes(fromHash)) return this.show(fromHash)
    if (names.includes(this.initialValue)) return this.show(this.initialValue)
    this.show(names[0])
  }

  showFromHash() {
    const names = this.tabNames()
    const fromHash = window.location.hash.replace(/^#/, "")
    if (names.includes(fromHash)) this.show(fromHash)
  }

  tabNames() {
    return this.panelTargets.map((p) => p.dataset.tabName)
  }

  show(name) {
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tabName !== name)
    })
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabName === name
      tab.classList.toggle("border-blue-600", active)
      tab.classList.toggle("text-blue-600", active)
      tab.classList.toggle("text-gray-500", !active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })
  }
}
