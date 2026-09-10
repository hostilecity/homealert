import { Controller } from "@hotwired/stimulus"

// Toggles the visibility of an event's camera snapshot. The <img> src is
// only set the first time the panel is expanded, so the (potentially large,
// ~500KB) image is never fetched unless the user actually asks to see it.
export default class extends Controller {
  static targets = ["button", "panel", "image", "label"]

  toggle() {
    const expanded = !this.panelTarget.classList.contains("hidden")

    if (expanded) {
      this.panelTarget.classList.add("hidden")
      if (this.hasLabelTarget) this.labelTarget.textContent = "Show snapshot"
    } else {
      if (!this.imageTarget.getAttribute("src")) {
        this.imageTarget.setAttribute("src", this.imageTarget.dataset.src)
      }
      this.panelTarget.classList.remove("hidden")
      if (this.hasLabelTarget) this.labelTarget.textContent = "Hide snapshot"
    }
  }
}
