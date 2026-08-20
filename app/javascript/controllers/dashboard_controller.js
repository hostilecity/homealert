import { Controller } from "@hotwired/stimulus"

// Listens for feed:updated events dispatched by feed_controller and
// replaces the stat cards with the fresh HTML included in the poll response.
export default class extends Controller {
  static targets = ["statCards"]

  connect() {
    this.handleFeedUpdated = this.onFeedUpdated.bind(this)
    this.element.addEventListener("feed:updated", this.handleFeedUpdated)
  }

  disconnect() {
    this.element.removeEventListener("feed:updated", this.handleFeedUpdated)
  }

  onFeedUpdated(event) {
    const newCards = event.detail?.statCards
    if (newCards && this.hasStatCardsTarget) {
      this.statCardsTarget.innerHTML = newCards.innerHTML
    }
  }
}
