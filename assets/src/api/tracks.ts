import type {
  InfiniteData,
  UseInfiniteQueryOptions,
} from "@tanstack/react-query";
import { queryClient } from "../api";
import type { Page, Track, UUID } from "../types";
import { ensureAutomaticInfiniteQueryData } from "../utils/ensureAutomaticInfiniteQueryData";
import { client, type RequestOptions } from "./client";

interface Params {
  artistId?: UUID;
  albumId?: UUID;
  sortBy?: "random" | "default";
}

export const trackQueries = {
  getTrack(trackId?: UUID, opts?: RequestOptions) {
    return {
      enabled: !!trackId,
      queryKey: ["track", trackId],
      queryFn: ({ signal }: { signal?: AbortSignal }) =>
        client.get<undefined, Track>(`/tracks/${trackId}`, { ...opts, signal }),
    };
  },

  paginateTracks(
    params: Params,
    opts?: RequestOptions,
  ): UseInfiniteQueryOptions<
    Page<Track>,
    Error,
    InfiniteData<Page<Track>>,
    readonly unknown[],
    unknown
  > {
    const queryKey = [
      "tracks",
      params.artistId,
      params.albumId,
      params.sortBy,
    ].filter((v) => v);

    const search = opts?.search ?? {};
    if (params.artistId) search.artist_id = params.artistId;
    if (params.albumId) search.album_id = params.albumId;
    if (params.sortBy === "random") {
      search.sort_by = "random";
      search.random_seed = Math.round(
        100000 + Math.random() * 1000000 * Date.now(),
      ).toString();
    }

    // For random queries we don't want to cache this data too long and make
    // sure a new request gets fresh data.
    let queryOpts = {};
    if (search.sort_by === "random") {
      queryOpts = {
        staleTime: 1,
        gcTime: 1,
      };
    }

    return {
      queryKey,
      ...queryOpts,
      initialPageParam: 1,
      getNextPageParam: (lastPage) => {
        if (!lastPage) return null;
        const nextPage = lastPage.pageNumber + 1;
        if (nextPage > lastPage.totalPages) return null;
        return nextPage;
      },
      queryFn: ({ pageParam, signal }) =>
        client.get<undefined, Page<Track>>(`/tracks`, {
          ...opts,
          signal,
          search: {
            ...search,
            page: pageParam as string,
          },
        }),
    };
  },
};

export const trackApi = {
  getTrack(trackId: UUID, opts?: RequestOptions) {
    return queryClient.ensureQueryData<Track>(
      trackQueries.getTrack(trackId, opts),
    );
  },

  paginateTracks(params: Params, opts?: RequestOptions) {
    return ensureAutomaticInfiniteQueryData<Track>(
      trackQueries.paginateTracks(params, opts),
      true,
    );
  },
};
