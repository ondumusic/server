/// <reference lib="webworker" />

declare const self: ServiceWorkerGlobalScope;

interface PrewarmMessage {
  type: "PREWARM";
  urls: string[];
}

interface PruneMessage {
  type: "PRUNE";
  urls: string[];
}

const CACHE_NAME = "artwork-v2";
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
  const cached = await cache.match(req, {
    ignoreVary: true,
    ignoreSearch: true,
  });
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
  const data = event.data as PrewarmMessage | PruneMessage | undefined;
  if (data?.type === "PREWARM") {
    event.waitUntil(prewarm(data.urls));
  } else if (data?.type === "PRUNE") {
    event.waitUntil(prune(data.urls));
  }
});

// Artwork urls look like /artwork/{kind}/{id}/{hash}/{variant}.jpg (e.g. kind
// "albums"), returns "{kind}/{id}/{hash}" or null for urls in another format
// (e.g. from before the artwork had a hash).
function artworkHash(url: string): string | null {
  const parts = new URL(url, self.location.origin).pathname.split("/");
  const [, prefix, kind, id, hash, variant] = parts;

  return parts.length === 6 &&
    prefix === "artwork" &&
    kind &&
    id &&
    hash &&
    variant
    ? `${kind}/${id}/${hash}`
    : null;
}

// Removes cached artwork that is no longer current, urls should contain the
// current artwork of all albums.
async function prune(urls: string[]): Promise<void> {
  const cache = await getCache();
  const current = new Set(urls.map(artworkHash));

  for (const request of await cache.keys()) {
    const hash = artworkHash(request.url);
    if (!hash || !current.has(hash)) {
      await cache.delete(request);
    }
  }
}

async function prewarm(urls: string[]): Promise<void> {
  const cache = await getCache();
  const exists = new Set((await cache.keys()).map((r) => r.url));
  const queue = urls.filter(
    (u) => !exists.has(new URL(u, self.location.origin).href),
  );
  if (queue.length === 0) return;

  const worker = async (): Promise<void> => {
    while (queue.length > 0) {
      const url = queue.shift();
      if (!url) return;

      // Skip if already cached (cheap, hits disk-backed cache storage)
      const existing = await cache.match(url);
      if (existing) continue;

      try {
        const res = await fetch(url, { priority: "low" } as RequestInit);
        if (res.status === 200 && !res.headers.has("Content-Range")) {
          await cache.put(url, res);
        }
      } catch {
        // It will still try it on-demand so can ignore error here.
      }
    }
  };

  await Promise.all(
    Array.from({ length: PREWARM_CONCURRENCY }, () => worker()),
  );
}
