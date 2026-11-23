/* Wishly shell. HTML and the compiled app are network-first so a deploy
   replaces main.dart.* instead of sticking to the old Flutter service worker.
   Images and fonts can still be reused offline. version.json is never cached. */
const CACHE = 'wishly-shell-v2';

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim()),
  );
});

function networkFirst(request) {
  return fetch(request)
    .then((response) => {
      if (response && response.ok && !new URL(request.url).pathname.endsWith('version.json')) {
        const copy = response.clone();
        caches.open(CACHE).then((cache) => cache.put(request, copy));
      }
      return response;
    })
    .catch(() => caches.match(request));
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  const path = url.pathname;
  const appCode =
    request.mode === 'navigate' ||
    path.endsWith('.html') ||
    path.endsWith('version.json') ||
    path.endsWith('flutter_bootstrap.js') ||
    path.endsWith('flutter.js') ||
    path.endsWith('flutter_service_worker.js') ||
    /main\.dart\./.test(path) ||
    path.endsWith('.mjs') ||
    path.endsWith('.wasm');
  if (appCode) {
    event.respondWith(networkFirst(request));
    return;
  }

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(request);
      const network = fetch(request)
        .then((response) => {
          if (response && response.ok) cache.put(request, response.clone());
          return response;
        })
        .catch(() => cached);
      return cached || network;
    }),
  );
});
