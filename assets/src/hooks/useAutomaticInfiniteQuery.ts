import {
  type InfiniteData,
  type UseInfiniteQueryOptions,
  useInfiniteQuery,
} from "@tanstack/react-query";
import type { Page } from "../types";

export interface Options<T> {
  enabled?: boolean;
  matchItem?(_hasItem: T): void;
}

export function useAutomaticInfiniteQuery<T>(
  query: UseInfiniteQueryOptions<
    Page<T>,
    Error,
    InfiniteData<Page<T>>,
    readonly unknown[],
    unknown
  >,
  opts: Options<T> = {},
) {
  const {
    error,
    data,
    fetchNextPage,
    hasNextPage,
    isFetching,
    isFetchingNextPage,
  } = useInfiniteQuery<Page<T>>({
    ...query,
    ...opts,
  });

  // This boolean stores whether or not there is a page matching the
  // given matchItem function
  let hasItem = null;
  const { matchItem } = opts;
  if (data && matchItem) {
    hasItem =
      data.pages.findIndex(
        ({ entries }) =>
          entries.findIndex((entry: T) => matchItem(entry)) !== -1,
      ) !== -1;
  }

  // Automatically fetch next pages until there is none
  if (hasNextPage && !isFetchingNextPage) {
    fetchNextPage();
  }

  return {
    data: data as InfiniteData<Page<T>>,
    error,
    isFetching,
    hasItem,
    isCompleted: !isFetching && hasNextPage === false,
    hasFirstPage: data && Array.isArray(data.pages) && data.pages.length >= 1,
  };
}
