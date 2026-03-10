const CACHE_NAME = 'ReApple Music-v6';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './manifest.json'
];

// Install Event: Cache the app shell and force activation
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
  self.skipWaiting(); // Force activation of new SW
});

// Fetch Event: Serve from cache if available, otherwise network
// Note: avoid rejecting respondWith to prevent console errors when cross-origin requests fail.
self.addEventListener('fetch', (event) => {
  const requestUrl = new URL(event.request.url);

  // Only handle same-origin requests via cache.
  // Cross-origin requests should be passed through (and errors handled gracefully).
  if (requestUrl.origin === self.location.origin) {
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        return cachedResponse || fetch(event.request).catch((err) => {
          console.warn('SW fetch failed for same-origin request:', event.request.url, err);
          return Response.error();
        });
      }).catch((err) => {
        console.warn('SW cache match failed:', err);
        return fetch(event.request).catch(() => Response.error());
      })
    );
  } else {
    // For cross-origin requests, just forward and handle failures silently.
    event.respondWith(
      fetch(event.request).catch((err) => {
        console.warn('SW cross-origin fetch failed:', event.request.url, err);
        return Response.error();
      })
    );
  }
});

// Activate Event: Clean up old caches, claim clients, and notify about updates
self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([
      // Take control of all clients
      self.clients.claim(),
      // Clean up old caches
      caches.keys().then((keyList) => {
        return Promise.all(keyList.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        }));
      }),
      // Notify all clients that update is available
      self.clients.matchAll().then((clients) => {
        clients.forEach((client) => {
          client.postMessage({ type: 'UPDATE_AVAILABLE' });
        });
      })
    ])
  );
});

// Update detection: Handle messages from clients
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
