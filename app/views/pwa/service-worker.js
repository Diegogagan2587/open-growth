const CACHE = "open-budget-v1"
const SHELL_PATHS = ["/quick-add/financial"]

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL_PATHS)))
})

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener("fetch", (event) => {
  const request = event.request
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok && shouldCache(request)) {
          const copy = response.clone()
          caches.open(CACHE).then((cache) => cache.put(request, copy))
        }
        return response
      })
      .catch(() => caches.match(request))
  )
})

function shouldCache(request) {
  const path = new URL(request.url).pathname
  return path === "/quick-add/financial" || ["script", "style", "image", "font"].includes(request.destination)
}
