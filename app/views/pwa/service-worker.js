// HomeAlert Service Worker
// Handles Web Push delivery and notification click-through.

// Take control immediately on install without waiting for existing tabs to close.
self.addEventListener("install", (event) => {
  self.skipWaiting()
})

// Claim all open clients so this service worker is active right away.
self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener("push", (event) => {
  if (!event.data) return

  const data = event.data.json()

  event.waitUntil(
    self.registration.showNotification(data.title, {
      body:  data.body,
      icon:  "/icon.png",
      badge: "/icon.png",
      data:  { path: data.path || "/" }
    })
  )
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
