import { Controller } from "@hotwired/stimulus"

// 削除の確認バナーを表示/取消する（表示切替のみ・クライアント側）。
// 確定は button_to の DELETE → Turbo Stream で行が消える。
// hidden と flex を入れ替えて display の競合を避ける。
export default class extends Controller {
  static targets = ["actions", "banner"]

  show() {
    this.swap(this.actionsTarget, this.bannerTarget)
  }

  hide() {
    this.swap(this.bannerTarget, this.actionsTarget)
  }

  swap(toHide, toShow) {
    toHide.classList.remove("flex")
    toHide.classList.add("hidden")
    toShow.classList.remove("hidden")
    toShow.classList.add("flex")
  }
}
