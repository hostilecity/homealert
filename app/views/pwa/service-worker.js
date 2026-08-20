// HomeAlert Service Worker
// Handles Web Push delivery and notification click-through.

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener("push", (event) => {
  let title = "HomeAlert"
  let body  = "New event received"
  let path  = "/"

  try {
    const data = event.data ? event.data.json() : {}
    title = data.title || title
    body  = data.body  || body
    path  = data.path  || path
  } catch (e) {
    // fall through with defaults
  }

  const promise = self.registration.showNotification(title, {
    body:    body,
    icon:    "/icon.png",
    badge:   "/icon.png",
    data:    { path: path },
    requireInteraction: false
  }).then(() => {
    console.log("[SW] showNotification resolved OK")
  }).catch((err) => {
    console.error("[SW] showNotification FAILED:", err)
  })

  event.waitUntil(promise)
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const path = event.notification.data?.path || "/"

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (new URL(client.url).pathname === path && "focus" in client) {
          return client.focus()
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(path)
      }
    })
  )
})
