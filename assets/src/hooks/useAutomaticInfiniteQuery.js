import { useInfiniteQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { api } from "../services/api";

export function useAutomaticInfiniteQuery({ path, queryKey }, opts = {}) {
  const {
    error,
    data,
    fetchNextPage,
    hasNextPage,
    isFetching,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey,
    initialPageParam: 1,
    getNextPageParam: (lastPage) => {
      const nextPage = lastPage.page_number + 1;
      if (nextPage > lastPage.total_pages) return null;
      return nextPage;
    },
    queryFn: ({ pageParam }) => api.get(path, { page: pageParam }),
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
