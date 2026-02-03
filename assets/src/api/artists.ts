import type {
  InfiniteData,
  UseInfiniteQueryOptions,
} from "@tanstack/react-query";
import { queryClient } from "../api/queryClient";
import type { Artist, Page, UUID } from "../types";
import { ensureAutomaticInfiniteQueryData } from "../utils/ensureAutomaticInfiniteQueryData";
import { client, type RequestOptions } from "./client";

export const artistQueries = {
  getArtist(artistId: UUID, opts?: RequestOptions) {
    return {
      queryKey: ["artist", artistId],
      queryFn: ({ signal }: { signal?: AbortSignal }) =>
        client.get<undefined, Artist>(`/artists/${artistId}`, {
          ...opts,
          signal,
        }),
    };
  },

  paginateArtists(
    opts?: RequestOptions,
  ): UseInfiniteQueryOptions<
    Page<Artist>,
    Error,
    InfiniteData<Page<Artist>>,
    readonly unknown[],
    unknown
  > {
    return {
      queryKey: ["artists"],
      initialPageParam: 1,
      getNextPageParam: (lastPage) => {
        if (!lastPage) return null;
        const nextPage = lastPage.pageNumber + 1;
        if (nextPage > lastPage.totalPages) return null;
        return nextPage;
      },
      queryFn: ({ pageParam, signal }) =>
        client.get<undefined, Page<Artist>>("/artists", {
          ...opts,
          signal,
          search: {
            ...(opts?.search ?? {}),
            page: pageParam as string,
          },
        }),
    };
  },
};

export const artistApi = {
  getArtist(artistId: UUID, opts?: RequestOptions) {
    return queryClient.ensureQueryData<Artist>(
      artistQueries.getArtist(artistId, opts),
    );
  },

  paginateArtists(opts?: RequestOptions) {
    return ensureAutomaticInfiniteQueryData<Artist>(
      artistQueries.paginateArtists(opts),
    );
  },
};
