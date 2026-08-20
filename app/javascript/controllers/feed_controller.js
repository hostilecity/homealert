import { Controller } from "@hotwired/stimulus"

const POLL_INTERVAL_MS = 12000 // 12 seconds

export default class extends Controller {
  static targets = ["list", "footer", "empty"]
  static values  = {
    url:       String,
    newestId:  Number,
    oldestId:  Number,
    oldestDate: String
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
      // No events rendered yet — check for first events
      await this.pollEmpty()
      return
    }

    const url = `${this.urlValue}?after_id=${this.newestIdValue}`
    const html = await this.fetchHtml(url)
    if (!html) return

    const fragment = this.parseFragment(html)
    if (!fragment.children.length) return

    // Prepend new rows above the existing list
    this.listTarget.prepend(...fragment.childNodes)

    // Update newestId to the first event id in the prepended chunk
    const firstRow = this.listTarget.querySelector("[data-event-id]")
    if (firstRow) this.newestIdValue = parseInt(firstRow.dataset.eventId, 10)

    // Hide the empty state if it was showing
    if (this.hasEmptyTarget) this.emptyTarget.remove()
  }

  async pollEmpty() {
    // When there are no events yet, poll for the very first one
    const url = `${this.urlValue}?after_id=0`
    const html = await this.fetchHtml(url)
    if (!html) return

    const fragment = this.parseFragment(html)
    if (!fragment.children.length) return

    this.listTarget.append(...fragment.childNodes)
    if (this.hasEmptyTarget) this.emptyTarget.remove()

    // Track newest and oldest from this initial batch
    this.updateCursors()
  }

  // ── View more: fetch events older than oldestId ───────────────────────────

  async loadMore() {
    if (this.oldestIdValue === 0) return

    const url = `${this.urlValue}?before_id=${this.oldestIdValue}&last_date=${this.oldestDateValue}`
    const html = await this.fetchHtml(url)
    if (!html) return

    const fragment = this.parseFragment(html)

    // The fragment contains rows + a replacement footer from the server
    const newFooter = fragment.querySelector("#view-more-footer")
    if (newFooter && this.hasFooterTarget) {
      this.footerTarget.replaceWith(newFooter)
    }

    // Insert all non-footer nodes before the footer
    const rows = [...fragment.childNodes].filter(
      n => !(n.id === "view-more-footer")
    )
    if (this.hasFooterTarget) {
      rows.forEach(n => this.listTarget.appendChild(n))
    }

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
    const rows = this.listTarget.querySelectorAll("[data-event-id]")
    if (!rows.length) return

    const ids = [...rows].map(r => parseInt(r.dataset.eventId, 10))
    this.newestIdValue = Math.max(...ids)
    this.oldestIdValue = Math.min(...ids)

    const oldestRow = [...rows].find(
      r => parseInt(r.dataset.eventId, 10) === this.oldestIdValue
    )
    if (oldestRow) this.oldestDateValue = oldestRow.dataset.eventDate
  }
}
