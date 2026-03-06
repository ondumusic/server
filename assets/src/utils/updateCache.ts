import type { QueryFilters } from "@tanstack/react-query";
import { queryClient } from "../api";
import type { Page } from "../types";

interface Result<T> {
  pages: Page<T>[];
}

interface Item {
  id: string;
  slug?: string;
  name: string;
  sortName?: string;
  __type: string;
}

type MixedData = Item | Result<Item>;

function hasSameId(a: Item, b: Item) {
  if (a.id === b.id) return true;
  if (a.slug && a.slug === b.slug) return true;
  return false;
}

function findRelevantPageIndex(pages: Page<Item>[], entry: Item): number {
  if (pages.length === 0) return 0;

  // Iterate through all pages
  for (let i = 0; i < pages.length; i++) {
    const page = pages[i];
    if (page.entries.length === 0) continue;

    // Should it be inserted before the last entry on this page?
    const lastEntry = page.entries[page.entries.length - 1];
    if (entry.name <= lastEntry.name) {
      return i;
    }
  }

  // Item should go on the last page
  return pages.length - 1;
}

export function updateCache(queryFilters: QueryFilters, items: Item[]) {
  if (items.length === 0) return;
  const firstItemType = items[0].__type;

  queryClient.setQueriesData(queryFilters, (oldData: MixedData) => {
    // For some reason undefined is also returned? Let's just return it.
    if (!oldData) return oldData;

    // Find a direct match
    if ("__type" in oldData && oldData.__type === firstItemType) {
      const newData = items.find((entry) => hasSameId(entry, oldData));
      if (newData) return newData;
      return oldData;
    }

    // Alright, time for more complicated pagination stuff.
    if ("pages" in oldData) {
      return updatePaginatedCache(oldData, [...items]);
    }
  });
}

function updatePaginatedCache(oldData: Result<Item>, items: Item[]) {
  // Is this page the same __type as our new items?
  if (!oldData.pages.length) return oldData;
  if (oldData.pages[0].__subtype !== items[0].__type) return oldData;

  // Find existing matches and replace those
  let newPages = oldData.pages.map((page) => {
    let changed = false;
    const newEntries = page.entries.map((oldEntry) => {
      const newEntryIndex = items.findIndex((entry) =>
        hasSameId(entry, oldEntry),
      );
      if (newEntryIndex === -1) return oldEntry;
      changed = true;
      return items.splice(newEntryIndex, 1)[0];
    });

    if (!changed) return page;
    return { ...page, entries: newEntries };
  });

  // If we have items left, we need to insert them (ideally in the correct page)
  if (items.length > 0) {
    items.forEach((entry) => {
      const relevantPageIndex = findRelevantPageIndex(newPages, entry);

      newPages = newPages.map((page, pageIndex) => {
        if (pageIndex !== relevantPageIndex) return page;

        const entries = page.entries;
        entries.push(entry);
        entries.sort((a: Item, b: Item) => {
          if (a.sortName && b.sortName) {
            if (a.sortName.toLowerCase() < b.sortName.toLowerCase()) return -1;
            if (a.sortName.toLowerCase() > b.sortName.toLowerCase()) return 1;
          } else {
            if (a.name.toLowerCase() < b.name.toLowerCase()) return -1;
            if (a.name.toLowerCase() > b.name.toLowerCase()) return 1;
          }

          return 0;
        });

        return {
          ...page,
          totalEntries: page.totalEntries + 1,
          entries: [...entries],
        };
      });
    });
  }

  return { ...oldData, pages: newPages };
}
