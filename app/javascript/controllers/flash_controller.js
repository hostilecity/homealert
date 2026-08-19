import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Begin fade-out after 3 seconds
    this.timeout = setTimeout(() => this.dismiss(), 3000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "translate-y-2")
    // Remove from DOM after the CSS transition completes (300ms)
    setTimeout(() => this.element.remove(), 300)
  }
}
