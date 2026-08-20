import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subscribeBtn", "unsubscribeBtn", "status"]
  static values  = { subscriptionId: Number }

  connect() {
    if (!this.supported()) {
      this.setStatus("Push notifications are not supported in this browser.")
      if (this.hasSubscribeBtnTarget) this.subscribeBtnTarget.disabled = true
    }
  }

  // ── Public actions ────────────────────────────────────────────────────────

  async subscribe() {
    const vapidKey = document.querySelector("meta[name='vapid-public-key']")?.content
    if (!vapidKey) {
      this.setStatus("Configuration error — please contact the administrator.")
      return
    }

    let registration
    try {
      registration = await navigator.serviceWorker.ready
    } catch (err) {
      this.setStatus("Service worker not available. Try reloading the page.")
      return
    }

    // Always unsubscribe any existing browser-side subscription first.
    // This forces Chrome to generate a fresh modern FCM endpoint rather
    // than reusing a stale legacy one (fcm/send/ format, deprecated June 2024).
    const existing = await registration.pushManager.getSubscription()
    if (existing) await existing.unsubscribe()

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

    const keys      = subscription.toJSON().keys || {}
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    const response = await fetch("/push_subscriptions", {
      method:  "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
      body: JSON.stringify({
        subscription: {
          endpoint:     subscription.endpoint,
          p256dh_key:   keys.p256dh,
          auth_key:     keys.auth,
          device_label: this.deviceLabel()
        }
      })
    })

    if (response.ok || response.status === 201) {
      window.location.reload()
    } else {
      const body = await response.json().catch(() => ({}))
      this.setStatus(body.error || "Failed to save subscription. Please try again.")
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
      // Best-effort: also unsubscribe the browser-side PushSubscription if
      // one exists. This may be absent if the service worker was unregistered.
      try {
        const reg = await Promise.race([
          navigator.serviceWorker.ready,
          new Promise((_, reject) => setTimeout(() => reject(new Error("timeout")), 2000))
        ])
        const sub = await reg.pushManager.getSubscription()
        await sub?.unsubscribe()
      } catch {
        // Service worker unavailable or timed out — server record already deleted, proceed
      }
      window.location.reload()
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  supported() {
    return "serviceWorker" in navigator && "PushManager" in window
  }

  deviceLabel() {
    const ua = navigator.userAgent
    let browser = "Browser"
    let os      = "Unknown OS"

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

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64  = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw     = atob(base64)
    return Uint8Array.from([...raw].map(c => c.charCodeAt(0)))
  }
}
