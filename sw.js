const CACHE_NAME = 'Preluded-Music-v12';
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
  self.skipWaiting();
});

// Fetch Event: Only cache same-origin static assets
self.addEventListener('fetch', (event) => {
  const requestUrl = new URL(event.request.url);

  // 1. Bypass Service Worker entirely for media (audio/video) or cross-origin requests
  if (
    event.request.destination === 'audio' ||
    event.request.destination === 'video' ||
    requestUrl.origin !== self.location.origin ||
    requestUrl.pathname.startsWith('/api') ||
    requestUrl.pathname.startsWith('/health')
  ) {
    // Let browser handle media and API requests natively
    return;
  }

  // 2. Same-origin app shell caching
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      return (
        cachedResponse ||
        fetch(event.request).catch((err) => {
          console.warn('SW fetch failed for same-origin request:', event.request.url, err);
          return Response.error();
        })
      );
    }).catch(() => fetch(event.request))
  );
});

// Activate Event: Clean up old caches, claim clients
self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([
      self.clients.claim(),
      caches.keys().then((keyList) => {
        return Promise.all(
          keyList.map((key) => {
            if (key !== CACHE_NAME) {
              return caches.delete(key);
            }
          })
        );
      }),
      self.clients.matchAll().then((clients) => {
        clients.forEach((client) => {
          client.postMessage({ type: 'UPDATE_AVAILABLE' });
        });
      })
    ])
  );
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
