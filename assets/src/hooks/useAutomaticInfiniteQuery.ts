import {
  useInfiniteQuery,
  useSuspenseInfiniteQuery,
} from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../services/api";
import type { Page } from "../types";

interface Params {
  path: string;
  queryKey: string[];
}

export interface Options<T> {
  enabled?: boolean;
  suspense?: boolean;
  suspendUntil?(_hasItem: T): void;
}

type Request = undefined;
type Response<T> = Page<T>;

export function useAutomaticInfiniteQuery<T>(
  { path, queryKey }: Params,
  opts: Options<T> = {},
) {
  const [ignoreSuspense, setIgnoreSuspense] = useState(false);
  const usingSuspense =
    opts.enabled !== false && !!opts.suspense && !ignoreSuspense;
  const queryFn = usingSuspense ? useSuspenseInfiniteQuery : useInfiniteQuery;

  const {
    error,
    data,
    fetchNextPage,
    hasNextPage,
    isFetching,
    isFetchingNextPage,
  } = queryFn<Page<T>>({
    queryKey,
    initialPageParam: 1,
    getNextPageParam: (lastPage) => {
      if (!lastPage) return null;
      const nextPage = lastPage.pageNumber + 1;
      if (nextPage > lastPage.totalPages) return null;
      return nextPage;
    },
    queryFn: ({ pageParam }) =>
      api.get<Request, Response<T>>(path, { page: pageParam as string }),
    ...opts,
  });

  // This boolean stores whether or not there is a page matching the
  // given suspendUntil function
  let hasItem = null;
  const { suspendUntil } = opts;
  if (data && suspendUntil) {
    hasItem =
      data.pages.findIndex(
        ({ entries }) =>
          entries.findIndex((entry: T) => suspendUntil(entry)) !== -1,
      ) !== -1;
  }

  // Automatically fetch next pages
  if (hasNextPage) {
    // Keep suspended until we have a matching item
    if (data && usingSuspense && opts.suspendUntil) {
      // Already busy, just return an empty promise
      if (isFetchingNextPage)
        throw new Promise((resolve) => setTimeout(resolve, 100));

      // Suspend for next page
      if (!hasItem) throw fetchNextPage();

      // We should be satisfied now, so stop using suspend
      setIgnoreSuspense(true);
    }

    // Keep loading next page until there is none
    if (!isFetchingNextPage) {
      fetchNextPage();
    }
  }

  return {
    data,
    error,
    isFetching,
    hasItem,
    isCompleted: !isFetching && hasNextPage === false,
    hasFirstPage: data && Array.isArray(data.pages) && data.pages.length >= 1,
  };
}
