const cacheName = "retrosnake-web-v8";

const assets = [
  "/",
  "/index.html",
  "/src/styles.css",
  "/src/main.js",
  "/public/manifest.webmanifest",
  "/apple-touch-icon.png",
  "/apple-touch-icon-precomposed.png",
  "/apple-touch-icon-120x120.png",
  "/apple-touch-icon-152x152.png",
  "/apple-touch-icon-167x167.png",
  "/apple-touch-icon-180x180.png",
  "/favicon.ico",
  "/public/icons/icon-192.png",
  "/public/icons/icon-512.png",
  "/public/icons/apple-touch-icon.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(cacheName).then((cache) => {
      return cache.addAll(assets);
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(keys.filter((key) => key !== cacheName).map((key) => caches.delete(key)));
    })
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;

  if (event.request.mode === "navigate") {
    event.respondWith(fetch(event.request).catch(() => caches.match("/index.html")));
    return;
  }

  if (event.request.url.endsWith("/src/main.js") || event.request.url.endsWith("/src/styles.css")) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const copy = response.clone();
          caches.open(cacheName).then((cache) => cache.put(event.request, copy));
          return response;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request).catch(() => Response.error());
    })
  );
});
