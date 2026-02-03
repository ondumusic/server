import { QueryCache, QueryClient } from "@tanstack/react-query";

interface Entry {
  __type: string;
  id: string;
}

interface Page {
  entries: Entry[];
}

interface PaginatedObject {
  pages: Page[];
}

type GenericData = PaginatedObject | Page | Entry;

const forceCacheItems = (data: GenericData | Array<GenericData>) => {
  if (!data) return;

  // Iterate over arrays.
  if (Array.isArray(data)) {
    data.forEach(forceCacheItems);
  }

  if (typeof data !== "object") return;

  // Iterate over paginated data when needed.
  if ("pages" in data) {
    data.pages.flatMap((page: Page) => forceCacheItems(page.entries));
    return;
  }

  // We only care about data with __type keys
  if (!("__type" in data)) return;

  // Store in cache
  queryClient.setQueryData([data.__type, data.id], data);

  // Iterate over the object to see if anything else needs caching,
  // for example album tracks.
  Object.values(data).forEach(forceCacheItems);
};

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: false,

      // Setting gcTime to Infinity so it keeps the cached items in memory
      // indefinitely (well, until you close/reload - it's still cache not
      // persisted). This prevents items from disappearing during playback.
      // Might look into a better solution in the future though.
      gcTime: Infinity,
    },
  },
  queryCache: new QueryCache({
    onSuccess: (data) => {
      forceCacheItems(data as GenericData);
    },
  }),
});
