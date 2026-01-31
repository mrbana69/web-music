const CACHE_NAME = 'ReApple Music';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './manifest.json'
];

// Install Event: Cache the app shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
});

// Fetch Event: Serve from cache if available, otherwise network
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (event.request.url.includes('index.html')) {
        // For index.html, check for updates
        return fetch(event.request).then((networkResponse) => {
          if (networkResponse.ok) {
            // Compare cached and network versions
            if (cachedResponse) {
              Promise.all([cachedResponse.clone().text(), networkResponse.clone().text()]).then(([cachedText, networkText]) => {
                if (cachedText !== networkText) {
                  // Notify clients of update
                  self.clients.matchAll().then((clients) => {
                    clients.forEach((client) => {
                      client.postMessage({ type: 'UPDATE_AVAILABLE' });
                    });
                  });
                }
              });
            }
            // Cache the new version
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, networkResponse.clone());
            });
            return networkResponse;
          } else if (cachedResponse) {
            return cachedResponse;
          }
        }).catch(() => {
          return cachedResponse;
        });
      } else {
        return cachedResponse || fetch(event.request);
      }
    })
  );
});

// Activate Event: Clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keyList) => {
      return Promise.all(keyList.map((key) => {
        if (key !== CACHE_NAME) {
          return caches.delete(key);
        }
      }));
    })
  );
});
