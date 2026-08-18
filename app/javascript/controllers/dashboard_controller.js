import { Controller } from "@hotwired/stimulus"
import { Chart, PieController, ArcElement, Tooltip, Legend } from "chart.js"

Chart.register(PieController, ArcElement, Tooltip, Legend)

// 月次ダッシュボード。月切り替えで GET /transactions/summary を fetch し、
// 支出合計・カテゴリ別円グラフ・未分類バッジを再描画する。ページ遷移はしない。
export default class extends Controller {
  static targets = ["canvas", "total", "monthLabel", "uncategorized", "error"]
  static values = { summaryUrl: String, transactionsUrl: String, month: String }

  connect() {
    this.initialMonth = this.monthValue
    // ブラウザの戻る/進む（popstate）で URL の月に追従して再描画する。
    this.onPopState = () => this.load(this.monthFromLocation(), { history: "none" })
    window.addEventListener("popstate", this.onPopState)
    // 初期表示は履歴を積まず replace（戻る操作で ?month 付き状態に戻れるように）。
    this.load(this.monthValue, { history: "replace" })
  }

  disconnect() {
    window.removeEventListener("popstate", this.onPopState)
    this.pendingController?.abort()
    this.chart?.destroy()
  }

  prev() {
    this.load(this.shiftMonth(this.monthValue, -1))
  }

  next() {
    this.load(this.shiftMonth(this.monthValue, 1))
  }

  async load(month, { history: historyMode = "push" } = {}) {
    this.hideError()
    // 直前の fetch を中断し、応答の着順逆転で古い月が反映されるのを防ぐ。
    this.pendingController?.abort()
    const controller = new AbortController()
    this.pendingController = controller

    let data
    try {
      const url = `${this.summaryUrlValue}?month=${encodeURIComponent(month)}`
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: controller.signal
      })
      if (!response.ok) throw new Error(`status ${response.status}`)
      data = await response.json()
    } catch (error) {
      if (error.name === "AbortError") return // 新しいリクエストに置き換えられた
      this.showError()
      return // 失敗時は URL も表示も据え置き
    }

    // fetch 成功後にのみ状態・表示・URL を更新する。
    this.monthValue = data.month
    this.render(data)
    this.updateHistory(historyMode, data.month)
  }

  updateHistory(mode, month) {
    if (mode === "none") return
    const url = `/?month=${encodeURIComponent(month)}`
    if (mode === "replace") history.replaceState({}, "", url)
    else history.pushState({}, "", url)
  }

  monthFromLocation() {
    const month = new URLSearchParams(window.location.search).get("month")
    return /^\d{4}-\d{2}$/.test(month || "") ? month : this.initialMonth
  }

  render(data) {
    if (this.hasMonthLabelTarget) this.monthLabelTarget.textContent = this.formatMonth(data.month)
    if (this.hasTotalTarget) this.totalTarget.textContent = this.formatYen(data.total)
    this.renderUncategorized(data)
    this.renderChart(data)
  }

  renderUncategorized(data) {
    if (!this.hasUncategorizedTarget) return
    const uncategorized = data.categories.find((c) => c.id === null)
    const count = uncategorized ? uncategorized.count : 0
    if (count > 0) {
      const href = `${this.transactionsUrlValue}?month=${encodeURIComponent(data.month)}&category=`
      this.uncategorizedTarget.innerHTML = ""
      const link = document.createElement("a")
      link.href = href
      link.className = "text-yellow-700 hover:underline"
      link.textContent = `未分類 ${count}件 ⚠️`
      this.uncategorizedTarget.appendChild(link)
    } else {
      this.uncategorizedTarget.textContent = ""
    }
  }

  renderChart(data) {
    // 円グラフは金額を持つカテゴリのみ（負値=返金は円グラフに載せない）。
    const slices = data.categories.filter((c) => c.amount > 0)
    const labels = slices.map((c) => c.name)
    const amounts = slices.map((c) => c.amount)

    if (this.chart) {
      this.chart.data.labels = labels
      this.chart.data.datasets[0].data = amounts
      this.chart.update()
      return
    }
    this.chart = new Chart(this.canvasTarget, {
      type: "pie",
      data: { labels, datasets: [{ data: amounts }] },
      options: { responsive: true, plugins: { legend: { position: "bottom" } } }
    })
  }

  // "2026-04" を ±n 月してゼロ埋め "YYYY-MM" を返す。
  shiftMonth(month, delta) {
    const [year, mon] = month.split("-").map(Number)
    const date = new Date(year, mon - 1 + delta, 1)
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, "0")
    return `${y}-${m}`
  }

  formatMonth(month) {
    const [year, mon] = month.split("-").map(Number)
    return `${year}年${mon}月`
  }

  formatYen(amount) {
    return `¥${Number(amount).toLocaleString("ja-JP")}`
  }

  showError() {
    if (this.hasErrorTarget) this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
  }
}
