import { useInfiniteQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { api } from "../services/api";
import type { Page } from "../types";

interface Params {
  path: string;
  queryKey: string[];
}

export interface Options {
  enabled?: boolean;
}

export function useAutomaticInfiniteQuery<T>(
  { path, queryKey }: Params,
  opts: Options = {},
) {
  const {
    error,
    data,
    fetchNextPage,
    hasNextPage,
    isFetching,
    isFetchingNextPage,
  } = useInfiniteQuery<Page<T>>({
    queryKey,
    initialPageParam: 1,
    getNextPageParam: (lastPage) => {
      const nextPage = lastPage.pageNumber + 1;
      if (nextPage > lastPage.totalPages) return null;
      return nextPage;
    },
    queryFn: ({ pageParam }) => api.get(path, { page: pageParam as string }),
    ...opts,
  });

  useEffect(() => {
    if (hasNextPage && !isFetchingNextPage && !isFetching && !error) {
      fetchNextPage();
    }
  }, [isFetching, error, hasNextPage, isFetchingNextPage, fetchNextPage]);

  return {
    data,
    error,
    isFetching,
    isCompleted: hasNextPage === false,
    hasFirstPage: Array.isArray(data) && data.length >= 1,
  };
}
