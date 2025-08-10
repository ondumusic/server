import type { Page, UUID } from "../types";
import { queryClient } from "../utils/queryClient";

type QueryKey = string[];

interface Result<T> {
  pages: Page<T>[];
}

interface Entry {
  id: UUID;
}

export function findCachedItem<T>(queryKey: QueryKey, id: UUID): T | undefined {
  const cache = queryClient.getQueryData<Result<T>>(queryKey);
  if (!cache) return undefined;
  const entries: T[] = cache.pages.flatMap((page: Page<T>) => page.entries);

  // It will be very rare to have a paginated item without an ID so we can
  // just use a generic Entry interface for this.
  return entries.find((entry) => (entry as Entry).id === id);
}
