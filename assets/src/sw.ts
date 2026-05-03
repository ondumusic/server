/// <reference lib="webworker" />

declare const self: ServiceWorkerGlobalScope;

interface PrewarmMessage {
  type: "PREWARM";
  urls: string[];
}

const CACHE_NAME = "artwork-v1";
const PREWARM_CONCURRENCY = 3;

let cachePromise: Promise<Cache>;
const getCache = () => {
  if (!cachePromise) cachePromise = caches.open(CACHE_NAME);
  return cachePromise;
};

function isArtworkRequest(url: URL): boolean {
  return url.pathname.startsWith("/artwork/");
}

async function handleArtwork(req: Request, event: FetchEvent) {
  const cache = await getCache();
  const cached = await cache.match(req);
  if (cached) return cached;

  try {
    const res = await fetch(req);
    if (res.ok) {
      // Don't block the response on cache write
      event.waitUntil(cache.put(req, res.clone()));
    }
    return res;
  } catch {
    return Response.error();
  }
}

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((n) => n.startsWith("artwork-") && n !== CACHE_NAME)
          .map((n) => caches.delete(n)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  if (isArtworkRequest(url)) {
    event.respondWith(handleArtwork(req, event));
    return;
  }
});

self.addEventListener("message", (event: ExtendableMessageEvent) => {
  const data = event.data as PrewarmMessage | undefined;
  if (data?.type === "PREWARM") {
    event.waitUntil(prewarm(data.urls));
  }
});

async function prewarm(urls: string[]): Promise<void> {
  const cache = await getCache();
  const queue = [...urls];

  const worker = async (): Promise<void> => {
    while (queue.length > 0) {
      const url = queue.shift();
      if (!url) return;

      // Skip if already cached (cheap, hits disk-backed cache storage)
      const existing = await cache.match(url);
      if (existing) continue;

      try {
        const res = await fetch(url, { priority: "low" } as RequestInit);
        if (res.ok) await cache.put(url, res);
      } catch {
        // Network error, just skip — on-demand fetch will retry when the user scrolls to it
      }
    }
  };

  await Promise.all(
    Array.from({ length: PREWARM_CONCURRENCY }, () => worker()),
  );
}
