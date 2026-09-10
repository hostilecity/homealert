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
  let image = null

  try {
    const data = event.data ? event.data.json() : {}
    title = data.title || title
    body  = data.body  || body
    path  = data.path  || path
    image = data.image || null
  } catch (e) {
    // fall through with defaults
  }

  const options = {
    body:  body,
    icon:  "/logo.png",
    badge: "/logo.png",
    data:  { path: path }
  }

  // Not all platforms render the `image` option (notably iOS Safari as of
  // writing), but it degrades gracefully to a text-only notification.
  if (image) options.image = image

  event.waitUntil(
    self.registration.showNotification(title, options)
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
