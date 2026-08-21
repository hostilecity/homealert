import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subscribeBtn", "status", "device", "currentBadge"]
  static values  = { url: String }

  connect() {
    this.reconcile().catch((err) => {
      console.error("Push status check failed:", err)
      this.showSubscribeButton("Could not check notification status for this device.")
    })
  }

  // ── Public actions ────────────────────────────────────────────────────────

  // Reflects the state of *this* browser onto the device list. Every device the
  // account has registered is rendered server-side; only the browser itself can
  // tell which row (if any) belongs to it, by comparing endpoint digests.
  async reconcile() {
    if (!this.supported()) {
      this.setStatus("Push notifications are not supported in this browser.")
      return
    }

    if (this.needsHomeScreenInstall()) {
      this.setStatus("Add HomeAlert to your Home Screen, then open it from there to enable notifications.")
      return
    }

    if (Notification.permission === "denied") {
      this.setStatus("Notifications are blocked for this site in your browser settings.")
      return
    }

    const registration = await this.registration()
    if (!registration) {
      this.setStatus("Service worker not available. Try reloading the page.")
      return
    }

    const subscription = await registration.pushManager.getSubscription()

    if (!subscription) {
      this.showSubscribeButton("Notifications are not enabled on this device.")
      return
    }

    // The browser may have re-issued the subscription under a new VAPID key
    // (server key rotation). Such a subscription can never be delivered to, so
    // drop it and let the user re-enable.
    if (!this.matchesServerKey(subscription)) {
      await subscription.unsubscribe().catch(() => {})
      this.showSubscribeButton("Notifications need to be re-enabled on this device.")
      return
    }

    const row = await this.deviceRowFor(subscription.endpoint)

    if (row) {
      this.markCurrentDevice(row)
      this.setStatus("Notifications are enabled on this device.")
      return
    }

    // The browser holds a subscription the server has never seen — typically
    // the record was removed on another device, or the push service rotated the
    // endpoint. Re-register it silently so this device keeps working.
    const saved = await this.persist(subscription)
    if (saved) {
      window.location.reload()
    } else {
      this.showSubscribeButton("Notifications are not enabled on this device.")
    }
  }

  async subscribe() {
    // Safari only honours a permission request that originates directly from a
    // user gesture, so this must run before any `await`.
    const permission = Notification.permission === "granted"
      ? "granted"
      : await Notification.requestPermission()

    if (permission !== "granted") {
      this.setStatus("Permission denied. Allow notifications for this site and try again.")
      return
    }

    const vapidKey = this.serverKey()
    if (!vapidKey) {
      this.setStatus("Configuration error — please contact the administrator.")
      return
    }

    const registration = await this.registration()
    if (!registration) {
      this.setStatus("Service worker not available. Try reloading the page.")
      return
    }

    if (this.hasSubscribeBtnTarget) this.subscribeBtnTarget.disabled = true

    // Reuse an existing browser subscription when it was issued under the
    // current VAPID key — unsubscribing needlessly rotates the endpoint and
    // leaves an orphaned record behind for this same device.
    let subscription   = await registration.pushManager.getSubscription()
    let staleEndpoint  = null

    if (subscription && !this.matchesServerKey(subscription)) {
      staleEndpoint = subscription.endpoint
      await subscription.unsubscribe().catch(() => {})
      subscription = null
    }

    if (!subscription) {
      try {
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly:      true,
          applicationServerKey: this.urlBase64ToUint8Array(vapidKey)
        })
      } catch (err) {
        console.error("Push subscription failed:", err)
        this.setStatus("Could not enable notifications. Check browser permissions.")
        if (this.hasSubscribeBtnTarget) this.subscribeBtnTarget.disabled = false
        return
      }
    }

    const saved = await this.persist(subscription, staleEndpoint)

    if (saved) {
      window.location.reload()
    } else if (this.hasSubscribeBtnTarget) {
      this.subscribeBtnTarget.disabled = false
    }
  }

  async unsubscribe(event) {
    const id = event.currentTarget.dataset.deviceId
    if (!id) return

    event.currentTarget.disabled = true

    const response = await fetch(`${this.urlValue}/${id}`, {
      method:  "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken() }
    })

    if (!response.ok) {
      event.currentTarget.disabled = false
      this.setStatus("Could not remove that device. Please try again.")
      return
    }

    // Only tear down the browser-side subscription when the row that was
    // removed is this very device; otherwise we would silently disable
    // notifications here while the user was removing their other device.
    if (event.currentTarget.closest("[data-endpoint-digest]")?.dataset.isCurrentDevice === "true") {
      try {
        const registration = await this.registration()
        const subscription = await registration?.pushManager.getSubscription()
        await subscription?.unsubscribe()
      } catch {
        // Service worker unavailable — the server record is already gone.
      }
    }

    window.location.reload()
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  async persist(subscription, previousEndpoint = null) {
    const keys = subscription.toJSON().keys || {}

    const response = await fetch(this.urlValue, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept":       "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify({
        subscription: {
          endpoint:          subscription.endpoint,
          p256dh_key:        keys.p256dh,
          auth_key:          keys.auth,
          device_label:      this.deviceLabel(),
          previous_endpoint: previousEndpoint
        }
      })
    })

    if (response.ok) return true

    const body = await response.json().catch(() => ({}))
    this.setStatus(body.error || "Failed to save subscription. Please try again.")
    return false
  }

  // ── DOM helpers ───────────────────────────────────────────────────────────

  async deviceRowFor(endpoint) {
    const digest = await this.sha256(endpoint)
    return this.deviceTargets.find(row => row.dataset.endpointDigest === digest)
  }

  markCurrentDevice(row) {
    row.dataset.isCurrentDevice = "true"
    const badge = row.querySelector("[data-push-target='currentBadge']")
    if (badge) badge.classList.remove("hidden")
    if (this.hasSubscribeBtnTarget) this.subscribeBtnTarget.classList.add("hidden")
  }

  showSubscribeButton(message) {
    this.setStatus(message)
    if (this.hasSubscribeBtnTarget) {
      this.subscribeBtnTarget.classList.remove("hidden")
      this.subscribeBtnTarget.disabled = false
    }
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  // ── Environment helpers ───────────────────────────────────────────────────

  supported() {
    return "serviceWorker" in navigator &&
           "PushManager"   in window &&
           "Notification"  in window
  }

  // iOS/iPadOS only exposes Web Push to a PWA launched from the Home Screen.
  needsHomeScreenInstall() {
    const ua      = navigator.userAgent
    const isIOS   = /iPhone|iPod|iPad/.test(ua) ||
                    (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)
    if (!isIOS) return false

    const standalone = window.navigator.standalone === true ||
                       window.matchMedia("(display-mode: standalone)").matches
    return !standalone
  }

  async registration() {
    try {
      return await Promise.race([
        navigator.serviceWorker.ready,
        new Promise((_, reject) => setTimeout(() => reject(new Error("timeout")), 5000))
      ])
    } catch {
      return null
    }
  }

  serverKey() {
    return document.querySelector("meta[name='vapid-public-key']")?.content
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  matchesServerKey(subscription) {
    const current = this.serverKey()
    const applied = subscription.options?.applicationServerKey
    if (!current || !applied) return true // cannot compare — assume valid

    const a = new Uint8Array(applied)
    const b = this.urlBase64ToUint8Array(current)
    return a.length === b.length && a.every((byte, i) => byte === b[i])
  }

  deviceLabel() {
    const ua = navigator.userAgent
    let browser = "Browser"
    let os      = "Unknown OS"

    if (/Chrome/.test(ua) && !/Edg|OPR/.test(ua)) browser = "Chrome"
    else if (/Safari/.test(ua) && !/Chrome/.test(ua)) browser = "Safari"
    else if (/Firefox/.test(ua)) browser = "Firefox"
    else if (/Edg/.test(ua)) browser = "Edge"

    if (/iPhone|iPod/.test(ua)) os = "iPhone"
    else if (/iPad/.test(ua)) os = "iPad"
    else if (/Android/.test(ua)) os = "Android"
    else if (/Mac/.test(ua)) os = "macOS"
    else if (/Windows/.test(ua)) os = "Windows"

    return `${browser} on ${os}`
  }

  async sha256(value) {
    const buffer = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))
    return [...new Uint8Array(buffer)].map(b => b.toString(16).padStart(2, "0")).join("")
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64  = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw     = atob(base64)
    return Uint8Array.from([...raw].map(c => c.charCodeAt(0)))
  }
}
