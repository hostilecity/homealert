import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subscribeBtn", "unsubscribeBtn", "status"]
  static values  = { subscriptionId: Number }

  async connect() {
    if (!this.supported()) {
      this.setStatus("Push notifications are not supported in this browser.")
      return
    }
    await this.syncUI()
  }

  // ── Public actions ────────────────────────────────────────────────────────

  async subscribe() {
    const registration = await navigator.serviceWorker.ready
    const vapidKey = document.querySelector("meta[name='vapid-public-key']")?.content
    if (!vapidKey) return

    let subscription
    try {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly:      true,
        applicationServerKey: this.urlBase64ToUint8Array(vapidKey)
      })
    } catch (err) {
      console.error("Push subscription failed:", err)
      this.setStatus("Could not enable notifications. Check browser permissions.")
      return
    }

    const keys    = subscription.toJSON().keys || {}
    const label   = this.deviceLabel()
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    const response = await fetch("/push_subscriptions", {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({
        subscription: {
          endpoint:    subscription.endpoint,
          p256dh_key:  keys.p256dh,
          auth_key:    keys.auth,
          device_label: label
        }
      })
    })

    if (response.ok || response.status === 201) {
      // Reload to let the server render the updated Settings section
      window.location.reload()
    } else {
      this.setStatus("Failed to save subscription. Please try again.")
    }
  }

  async unsubscribe() {
    const id = this.subscriptionIdValue
    if (!id) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const response  = await fetch(`/push_subscriptions/${id}`, {
      method:  "DELETE",
      headers: { "X-CSRF-Token": csrfToken }
    })

    if (response.ok) {
      // Also unsubscribe the browser-side PushSubscription
      const registration = await navigator.serviceWorker.ready
      const sub = await registration.pushManager.getSubscription()
      await sub?.unsubscribe()
      window.location.reload()
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  supported() {
    return "serviceWorker" in navigator && "PushManager" in window
  }

  async syncUI() {
    const registration = await navigator.serviceWorker.ready
    const sub = await registration.pushManager.getSubscription()
    // UI state is handled server-side; this is a no-op for now but can
    // be used to sync the browser subscription state if needed.
    if (!sub && this.hasUnsubscribeBtnTarget) {
      this.unsubscribeBtnTarget.closest("[data-push-device]")?.remove()
    }
  }

  deviceLabel() {
    const ua = navigator.userAgent
    let browser = "Browser"
    let os = "Unknown OS"

    if (/Chrome/.test(ua) && !/Edg|OPR/.test(ua)) browser = "Chrome"
    else if (/Safari/.test(ua) && !/Chrome/.test(ua)) browser = "Safari"
    else if (/Firefox/.test(ua)) browser = "Firefox"
    else if (/Edg/.test(ua)) browser = "Edge"

    if (/iPhone|iPad/.test(ua)) os = "iOS"
    else if (/Android/.test(ua)) os = "Android"
    else if (/Mac/.test(ua)) os = "macOS"
    else if (/Windows/.test(ua)) os = "Windows"

    return `${browser} on ${os}`
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  // Converts a URL-safe base64 VAPID public key to a Uint8Array
  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64  = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw     = atob(base64)
    return Uint8Array.from([...raw].map(c => c.charCodeAt(0)))
  }
}
