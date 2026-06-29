const cacheName = "retrosnake-web-v2";

const assets = [
  "./",
  "./index.html",
  "./src/styles.css",
  "./src/main.js",
  "./public/manifest.webmanifest",
  "./public/icons/icon-192.png",
  "./public/icons/icon-512.png",
  "./public/icons/apple-touch-icon.png",
  "./public/sounds/background.mp3",
  "./public/sounds/eat.wav",
  "./public/sounds/gameover.wav",
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
      return cached || fetch(event.request);
    })
  );
});
