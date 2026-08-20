import { Controller } from "@hotwired/stimulus"

// Persists a boolean preference toggle immediately on click.
// Expects:
//   data-toggle-url-value     — PATCH endpoint
//   data-toggle-field-value   — param name (e.g. "doorbell_pressed")
//   data-toggle-checked-value — current state (true/false)
export default class extends Controller {
  static targets = ["button"]
  static values  = {
    url:     String,
    field:   String,
    checked: Boolean
  }

  async toggle() {
    if (this.pending) return  // ignore concurrent clicks
    this.pending = true

    if (this.hasButtonTarget) this.buttonTarget.disabled = true

    const newValue  = !this.checkedValue
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    // Optimistically update UI
    this.checkedValue = newValue
    this.updateButtonAppearance(newValue)

    try {
      const response = await fetch(this.urlValue, {
        method:  "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ preference: { [this.fieldValue]: newValue } })
      })

      if (!response.ok) {
        // Revert on failure
        this.checkedValue = !newValue
        this.updateButtonAppearance(!newValue)
      }
    } finally {
      this.pending = false
      if (this.hasButtonTarget) this.buttonTarget.disabled = false
    }
  }

  updateButtonAppearance(checked) {
    if (!this.hasButtonTarget) return
    const btn  = this.buttonTarget
    const knob = btn.querySelector("span")

    if (checked) {
      btn.classList.add("bg-indigo-600")
      btn.classList.remove("bg-gray-700")
      knob?.classList.add("translate-x-5")
      knob?.classList.remove("translate-x-0")
      btn.setAttribute("aria-checked", "true")
    } else {
      btn.classList.remove("bg-indigo-600")
      btn.classList.add("bg-gray-700")
      knob?.classList.remove("translate-x-5")
      knob?.classList.add("translate-x-0")
      btn.setAttribute("aria-checked", "false")
    }
  }
}
