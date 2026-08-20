import { Controller } from "@hotwired/stimulus"

const POLL_INTERVAL_MS = 12000 // 12 seconds

export default class extends Controller {
  static targets = ["list", "footer", "empty"]
  static values  = {
    url:        String,
    newestId:   Number,
    oldestId:   Number,
    oldestDate: String
  }

  connect() {
    this.poll()
    this.timer = setInterval(() => this.poll(), POLL_INTERVAL_MS)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  // ── Polling: replace the entire list if anything is new ──────────────────

  async poll() {
    const url = `${this.urlValue}?poll=1&newest_id=${this.newestIdValue}`
    const response = await this.fetchResponse(url)
    if (!response) return

    // 204 No Content means nothing has changed — do nothing
    if (response.status === 204) return

    const html = await response.text()
    if (!html.trim()) return

    // Replace the entire list with the freshly-rendered server HTML.
    // This is safe because the feed is small (≤ 10 rows) and eliminates
    // all DOM-merging complexity that caused duplicate date headers.
    this.listTarget.innerHTML = html

    if (this.hasEmptyTarget) this.emptyTarget.remove()
    this.updateCursors()
  }

  // ── View more: append next page of older events ───────────────────────────

  async loadMore() {
    if (this.oldestIdValue === 0) return

    const url = `${this.urlValue}?before_id=${this.oldestIdValue}&last_date=${this.oldestDateValue}`
    const response = await this.fetchResponse(url)
    if (!response || response.status === 204) return

    const html = await response.text()
    if (!html) return

    const fragment = this.parseFragment(html)

    // Replace the footer with the server-rendered one (hides button when no more pages)
    const newFooter = fragment.querySelector("#view-more-footer")
    if (newFooter && this.hasFooterTarget) {
      this.footerTarget.replaceWith(newFooter)
    }

    // Append event rows to the list
    const rows = [...fragment.childNodes].filter(n => n.id !== "view-more-footer")
    rows.forEach(n => this.listTarget.appendChild(n))

    this.updateCursors()
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  async fetchResponse(url) {
    try {
      return await fetch(url, {
        headers: { "X-Requested-With": "XMLHttpRequest" }
      })
    } catch {
      return null
    }
  }

  parseFragment(html) {
    const tpl = document.createElement("template")
    tpl.innerHTML = html
    return tpl.content
  }

  updateCursors() {
    const rows = [...this.listTarget.querySelectorAll("[data-event-id]")]
    if (!rows.length) return

    const ids = rows.map(r => parseInt(r.dataset.eventId, 10))
    this.newestIdValue = Math.max(...ids)
    this.oldestIdValue = Math.min(...ids)

    const oldestRow = rows.find(r => parseInt(r.dataset.eventId, 10) === this.oldestIdValue)
    if (oldestRow) this.oldestDateValue = oldestRow.dataset.eventDate
  }
}
