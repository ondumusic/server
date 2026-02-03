import type {
  InfiniteData,
  UseInfiniteQueryOptions,
} from "@tanstack/react-query";
import type { Page } from "../types";
import { queryClient } from "../utils/queryClient";

type QueryFunction<T> = ({
  pageParam,
}: {
  pageParam: unknown;
}) => Promise<Page<T>>;

export async function* ensureAutomaticInfiniteQueryData<T>(
  query: UseInfiniteQueryOptions<
    Page<T>,
    Error,
    InfiniteData<Page<T>>,
    readonly unknown[],
    unknown
  >,
) {
  if (typeof query.queryFn !== "function") return;
  const queryFn = query.queryFn as QueryFunction<T>;

  const result = await queryClient.ensureInfiniteQueryData(query);
  const totalPages = result.pages[0].totalPages ?? 0;

  let pageIndex = 0;
  while (pageIndex < totalPages) {
    const prevPage = result.pages[pageIndex - 1];
    const prevPageParam = result.pageParams[pageIndex - 1];
    let currentPage = result.pages[pageIndex];

    if (!currentPage) {
      const nextPage =
        query.getNextPageParam(
          prevPage,
          result.pages,
          prevPageParam,
          result.pageParams,
        ) ?? query.initialPageParam;
      currentPage = await queryFn({ pageParam: nextPage });

      if (!currentPage) break;
      result.pages.push(currentPage);
      result.pageParams.push(nextPage);
      queryClient.setQueryData(query.queryKey, result);
    }

    const entries = currentPage?.entries;
    for (const entry of entries) {
      yield entry;
    }

    pageIndex++;
  }
}
