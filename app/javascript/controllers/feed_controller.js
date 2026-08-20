import { Controller } from "@hotwired/stimulus"

const POLL_INTERVAL_MS = 12000 // 12 seconds

export default class extends Controller {
  static targets = ["list", "footer", "empty"]
  static values  = {
    url:        String,
    newestId:   Number,
    oldestId:   Number,
    oldestDate: String,
    newestDate: String
  }

  connect() {
    this.poll()
    this.timer = setInterval(() => this.poll(), POLL_INTERVAL_MS)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  // ── Polling: fetch events newer than newestId ─────────────────────────────

  async poll() {
    if (this.newestIdValue === 0) {
      await this.pollEmpty()
      return
    }

    // Pass first_date so the server can suppress the leading divider if the
    // newest returned group shares a date with the current top of the feed.
    const url = `${this.urlValue}?after_id=${this.newestIdValue}&first_date=${this.newestDateValue}`
    const html = await this.fetchHtml(url)
    if (!html || !html.trim()) return

    const fragment = this.parseFragment(html)
    if (!fragment.children.length) return

    // Server returns events oldest-first; prepending puts newest at the top.
    this.listTarget.prepend(...fragment.childNodes)

    if (this.hasEmptyTarget) this.emptyTarget.remove()
    this.updateCursors()
  }

  async pollEmpty() {
    const url = `${this.urlValue}?after_id=0`
    const html = await this.fetchHtml(url)
    if (!html || !html.trim()) return

    const fragment = this.parseFragment(html)
    if (!fragment.children.length) return

    this.listTarget.append(...fragment.childNodes)
    if (this.hasEmptyTarget) this.emptyTarget.remove()
    this.updateCursors()
  }

  // ── View more: fetch events older than oldestId ───────────────────────────

  async loadMore() {
    if (this.oldestIdValue === 0) return

    const url = `${this.urlValue}?before_id=${this.oldestIdValue}&last_date=${this.oldestDateValue}`
    const html = await this.fetchHtml(url)
    if (!html) return

    const fragment = this.parseFragment(html)

    // Replace the footer in-place with the server-rendered one
    const newFooter = fragment.querySelector("#view-more-footer")
    if (newFooter && this.hasFooterTarget) {
      this.footerTarget.replaceWith(newFooter)
    }

    // Append event rows to the list (before the footer)
    const rows = [...fragment.childNodes].filter(n => n.id !== "view-more-footer")
    rows.forEach(n => this.listTarget.appendChild(n))

    this.updateCursors()
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  async fetchHtml(url) {
    try {
      const response = await fetch(url, {
        headers: { "X-Requested-With": "XMLHttpRequest" }
      })
      if (!response.ok) return null
      return response.text()
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

    const byId = rows.map(r => parseInt(r.dataset.eventId, 10))
    this.newestIdValue = Math.max(...byId)
    this.oldestIdValue = Math.min(...byId)

    const newestRow = rows.find(r => parseInt(r.dataset.eventId, 10) === this.newestIdValue)
    const oldestRow = rows.find(r => parseInt(r.dataset.eventId, 10) === this.oldestIdValue)
    if (newestRow) this.newestDateValue = newestRow.dataset.eventDate
    if (oldestRow) this.oldestDateValue = oldestRow.dataset.eventDate
  }
}
