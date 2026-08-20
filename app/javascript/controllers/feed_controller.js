import { Controller } from "@hotwired/stimulus"

const POLL_INTERVAL_MS = 12000 // 12 seconds

export default class extends Controller {
  static targets = ["list", "footer", "empty"]
  static values  = {
    url:               String,
    newestId:          Number,
    oldestOccurredAt:  String  // ISO string of the oldest visible event's occurred_at
  }

  connect() {
    this.poll()
    this.timer = setInterval(() => this.poll(), POLL_INTERVAL_MS)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  // ── Polling: replace the entire list + footer if anything is new ──────────

  async poll() {
    const url = `${this.urlValue}?poll=1&newest_id=${this.newestIdValue}`
    const response = await this.fetchResponse(url)
    if (!response) return

    // 204 No Content — nothing changed, leave DOM alone
    if (response.status === 204) return

    const html = await response.text()
    if (!html.trim()) return

    const fragment = this.parseFragment(html)

    // Pull the footer out of the fragment and replace the footer target
    const newFooter = fragment.querySelector("#view-more-footer")
    if (newFooter && this.hasFooterTarget) {
      this.footerTarget.replaceWith(newFooter)
    }

    // Remaining element nodes are the event rows + dividers
    const rows = elementNodes(fragment)
    this.listTarget.innerHTML = ""
    rows.forEach(n => this.listTarget.appendChild(n))

    if (this.hasEmptyTarget) this.emptyTarget.remove()
    this.updateCursors()
  }

  // ── View more: append next page of older events ───────────────────────────

  async loadMore() {
    if (!this.oldestOccurredAtValue) return

    const url = `${this.urlValue}?before_occurred_at=${encodeURIComponent(this.oldestOccurredAtValue)}&last_date=${this.oldestDate()}`
    const response = await this.fetchResponse(url)
    if (!response || response.status === 204) return

    const html = await response.text()
    if (!html) return

    const fragment = this.parseFragment(html)

    // Replace footer target (hides button when no more pages)
    const newFooter = fragment.querySelector("#view-more-footer")
    if (newFooter) {
      if (this.hasFooterTarget) {
        this.footerTarget.replaceWith(newFooter)
      } else {
        // Footer target may be missing if events first arrived via polling;
        // insert it after the list in that case.
        this.listTarget.insertAdjacentElement("afterend", newFooter)
      }
    }

    // Append only element nodes (filters out whitespace text nodes)
    elementNodes(fragment).forEach(n => this.listTarget.appendChild(n))

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
    // Use DOM position (first = newest, last = oldest) rather than max/min over
    // IDs, since the feed is ordered by occurred_at which may diverge from ID
    // order if webhook delivery is delayed or clocks are skewed.
    const rows = [...this.listTarget.querySelectorAll("[data-event-id]")]
    if (!rows.length) return

    const newestRow = rows[0]
    const oldestRow = rows[rows.length - 1]

    this.newestIdValue         = parseInt(newestRow.dataset.eventId, 10)
    this.oldestOccurredAtValue = oldestRow.dataset.eventOccurredAt
  }

  oldestDate() {
    const rows = [...this.listTarget.querySelectorAll("[data-event-id]")]
    if (!rows.length) return ""
    return rows[rows.length - 1].dataset.eventDate || ""
  }
}

// Returns only Element nodes from a DocumentFragment, filtering whitespace text nodes
function elementNodes(fragment) {
  return [...fragment.childNodes].filter(n => n.nodeType === Node.ELEMENT_NODE)
}
