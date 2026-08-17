import { Controller } from "@hotwired/stimulus"

// フォーム内のコントロール変更で、その場でフォームを送信する（Turbo が引き受ける）。
// 例: 一覧のカテゴリ select 変更 → PATCH categorize → Turbo Stream で行を差し替え。
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
