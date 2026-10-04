import { Controller } from "@hotwired/stimulus"
import {
  Chart, DoughnutController, ArcElement, Tooltip, Legend,
  BarController, BarElement, CategoryScale, LinearScale
} from "chart.js"

Chart.register(DoughnutController, ArcElement, Tooltip, Legend,
  BarController, BarElement, CategoryScale, LinearScale)

// カテゴリ別ドーナツの配色（デザインシステム「家計簿ノート」のカテゴリ配色）。
// 自動彩色プラグインを積まない構成のため明示指定し、先頭から循環させる。
// 「その他」「未分類」は末尾の鈍色に固定する。
const CATEGORY_COLORS = [
  "#c23b2b", "#2f6d8a", "#d8a23a", "#4b8f6e", "#9c5fb0", "#d9774e",
  "#3f7cc0", "#7a8b4f", "#c06597", "#5aa0a0", "#8a6d53"
]
const OTHER_COLOR = "#6b7794"
// 月別推移の棒グラフ色（当月＝朱 / それ以外＝非強調）。
const BAR_CURRENT = "#c23b2b"
const BAR_OTHER = "#ddd6c6"

// 月次ダッシュボード。月切り替えで GET /transactions/summary を fetch し、
// 支出合計・カテゴリ別円グラフ・未分類バッジを再描画する。ページ遷移はしない。
export default class extends Controller {
  static targets = [
    "canvas", "trendCanvas", "legend", "total", "monthLabel", "uncategorized", "recentAverage",
    "monthlyAverageOverall", "monthlyAverageCategories", "error"
  ]
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
    // 破棄後は参照を消す。同じ DOM 要素が再接続されると Stimulus は同じ instance を
    // 再利用するため、破棄済み Chart を掴んだままだと renderChart/renderTrend の update が失敗する。
    this.chart?.destroy()
    this.chart = null
    this.trendChart?.destroy()
    this.trendChart = null
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
    this.renderRecentAverage(data.recent_average)
    this.renderMonthlyAverage(data.monthly_average)
    this.renderUncategorized(data)
    this.renderChart(data)
    this.renderTrend(data)
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
      link.className = "badge"
      link.textContent = `未分類 ${count}件`
      this.uncategorizedTarget.appendChild(link)
    } else {
      this.uncategorizedTarget.textContent = ""
    }
  }

  // 直近3ヶ月平均との比較を表示する。支出増（当月>平均）は赤、減は緑、直近にデータが無ければ灰で注記。
  renderRecentAverage(recent) {
    if (!this.hasRecentAverageTarget) return
    const target = this.recentAverageTarget
    target.classList.remove("text-red-600", "text-green-700", "text-gray-500")

    const window = recent ? recent.window : 3
    if (!recent || recent.months === 0) {
      target.textContent = `直近${window}ヶ月平均比 —（比較できるデータなし）`
      target.classList.add("text-gray-500")
      return
    }
    if (recent.rate === null) {
      // データはあるが基準が正でない（返金相殺など）→ 率を出せない。
      target.textContent = `直近${window}ヶ月平均比 —（比較できません）`
      target.classList.add("text-gray-500")
      return
    }

    const mark = recent.diff > 0 ? "+" : recent.diff < 0 ? "−" : "±"
    const rate = `${mark}${Math.abs(recent.rate).toFixed(1)}%`
    const yen = `${mark}¥${Math.abs(recent.diff).toLocaleString("ja-JP")}`
    target.textContent = `直近${recent.window}ヶ月平均比 ${rate}（${yen}）`
    target.classList.add(recent.diff > 0 ? "text-red-600" : recent.diff < 0 ? "text-green-700" : "text-gray-500")
  }

  // 月平均支出（全体＋カテゴリ別）を表示する。データが無ければ「—」。
  renderMonthlyAverage(avg) {
    const hasData = avg && avg.months > 0
    if (this.hasMonthlyAverageOverallTarget) {
      this.monthlyAverageOverallTarget.textContent = hasData ? this.formatYen(avg.overall) : "—"
    }
    if (!this.hasMonthlyAverageCategoriesTarget) return

    const list = this.monthlyAverageCategoriesTarget
    list.innerHTML = ""
    if (!hasData) return

    avg.categories.forEach((category) => {
      const item = document.createElement("li")
      const name = document.createElement("span")
      name.className = "nm"
      name.textContent = category.name
      const amount = document.createElement("span")
      amount.className = "num"
      amount.textContent = this.formatYen(category.average)
      item.append(name, amount)
      list.appendChild(item)
    })
  }

  renderChart(data) {
    // ドーナツは金額を持つカテゴリのみ（負値=返金は載せない）。「その他/未分類」は鈍色に固定。
    const slices = data.categories.filter((c) => c.amount > 0)
    const labels = slices.map((c) => c.name)
    const amounts = slices.map((c) => c.amount)
    let ci = 0
    const colors = slices.map((c) => {
      if (c.id === null || c.name === "その他") return OTHER_COLOR
      return CATEGORY_COLORS[ci++ % CATEGORY_COLORS.length]
    })

    this.renderLegend(slices, colors)

    if (this.chart) {
      this.chart.data.labels = labels
      this.chart.data.datasets[0].data = amounts
      this.chart.data.datasets[0].backgroundColor = colors
      this.chart.update()
      return
    }
    this.chart = new Chart(this.canvasTarget, {
      type: "doughnut",
      data: { labels, datasets: [{ data: amounts, backgroundColor: colors, borderWidth: 0 }] },
      options: {
        responsive: true, maintainAspectRatio: false, cutout: "62%",
        plugins: { legend: { display: false } }
      }
    })
  }

  // カテゴリ名＋金額の凡例を描画する（Chart.js 既定の凡例は使わず金額を併記）。
  renderLegend(slices, colors) {
    if (!this.hasLegendTarget) return
    const list = this.legendTarget
    list.innerHTML = ""
    slices.forEach((c, i) => {
      const item = document.createElement("li")
      const dot = document.createElement("i")
      dot.style.background = colors[i]
      const name = document.createElement("span")
      name.textContent = c.name
      const amount = document.createElement("b")
      amount.className = "num"
      amount.textContent = this.formatYen(c.amount)
      item.append(dot, name, amount)
      list.appendChild(item)
    })
  }

  // 直近数ヶ月の支出推移を棒グラフで描画する。表示中の月を強調色にする。
  renderTrend(data) {
    if (!this.hasTrendCanvasTarget) return
    const totals = data.monthly_totals || []
    const labels = totals.map((t) => this.formatMonth(t.month))
    const amounts = totals.map((t) => t.total)
    const colors = totals.map((t) => (t.month === data.month ? BAR_CURRENT : BAR_OTHER))

    if (this.trendChart) {
      this.trendChart.data.labels = labels
      this.trendChart.data.datasets[0].data = amounts
      this.trendChart.data.datasets[0].backgroundColor = colors
      this.trendChart.update()
      return
    }
    this.trendChart = new Chart(this.trendCanvasTarget, {
      type: "bar",
      data: { labels, datasets: [{ data: amounts, backgroundColor: colors, borderRadius: 4 }] },
      options: {
        responsive: true, maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true } }
      }
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
