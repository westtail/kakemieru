import { Controller } from "@hotwired/stimulus"

// フラッシュメッセージを一定時間後にフェードアウトして消す。閉じるボタンでも即消し。
// フェードは要素の transition-opacity（.flash）に任せ、opacity-0 を付けて消す。
export default class extends Controller {
  static values = { delay: { type: Number, default: 4000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    clearTimeout(this.timeout)
    this.element.classList.add("opacity-0")
    // フェード完了後に DOM から除去（transition が無い環境向けに保険のタイマーも張る）。
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    setTimeout(() => this.element.remove(), 600)
  }
}
