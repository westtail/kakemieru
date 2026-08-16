import { Controller } from "@hotwired/stimulus"

// クリックで開閉するドロップダウン。外側クリック・Esc で閉じる。
// button（トグル）と menu（表示切替する中身）を target に取る。
export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    this.closeOnOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.closeOnEscape = (event) => {
      if (event.key === "Escape") this.close()
    }
    document.addEventListener("click", this.closeOnOutsideClick)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    this.syncExpanded()
  }

  close() {
    if (this.menuTarget.classList.contains("hidden")) return
    this.menuTarget.classList.add("hidden")
    this.syncExpanded()
  }

  syncExpanded() {
    if (!this.hasButtonTarget) return
    const open = !this.menuTarget.classList.contains("hidden")
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }
}
