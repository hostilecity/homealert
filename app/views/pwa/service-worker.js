// HomeAlert Service Worker
// Handles Web Push delivery and notification click-through.

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener("push", (event) => {
  console.log("[SW] push event received", event)
  console.log("[SW] event.data:", event.data)

  if (!event.data) {
    console.warn("[SW] push event has no data — showing fallback notification")
    event.waitUntil(
      self.registration.showNotification("HomeAlert", {
        body: "New event received",
        icon: "/icon.png"
      })
    )
    return
  }

  let data
  try {
    data = event.data.json()
    console.log("[SW] parsed push data:", data)
  } catch (e) {
    console.error("[SW] failed to parse push data as JSON:", e)
    console.log("[SW] raw text:", event.data.text())
    event.waitUntil(
      self.registration.showNotification("HomeAlert", {
        body: "New event received",
        icon: "/icon.png"
      })
    )
    return
  }

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
