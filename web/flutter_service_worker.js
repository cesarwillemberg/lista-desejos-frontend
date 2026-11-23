/* Replaces Flutter's old cache-first service worker. Browsers that already
   registered this script URL install this file, drop every cache, and unregister
   so the next load is the current deploy. */
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(Promise.resolve());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.map((key) => caches.delete(key))))
      .then(() => self.clients.matchAll({ type: 'window' }))
      .then((clients) => Promise.all(clients.map((client) => client.navigate(client.url))))
      .then(() => self.registration.unregister()),
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
