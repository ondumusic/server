import { queryClient } from "../utils/queryClient";

export function findCachedItem(queryKey, id) {
  const cache = queryClient.getQueryData(queryKey);
  if (!cache) return;
  const entries = cache.pages.flatMap((page) => page.entries);
  return entries.find((entry) => entry.id === id);
}
