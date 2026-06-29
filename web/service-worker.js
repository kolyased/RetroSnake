const cacheName = "retrosnake-web-v3";

const assets = [
  "/",
  "/index.html",
  "/src/styles.css",
  "/src/main.js",
  "/public/manifest.webmanifest",
  "/apple-touch-icon.png",
  "/public/icons/icon-192.png",
  "/public/icons/icon-512.png",
  "/public/icons/apple-touch-icon.png",
  "/public/sounds/background.mp3",
  "/public/sounds/eat.wav",
  "/public/sounds/gameover.wav",
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

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request).catch(() => {
        if (event.request.mode === "navigate") {
          return caches.match("/index.html");
        }

        return Response.error();
      });
    })
  );
});
