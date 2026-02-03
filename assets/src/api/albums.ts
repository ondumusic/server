import type {
  InfiniteData,
  UseInfiniteQueryOptions,
} from "@tanstack/react-query";
import { queryClient } from "../api";
import type { Album, Page, UUID } from "../types";
import { ensureAutomaticInfiniteQueryData } from "../utils/ensureAutomaticInfiniteQueryData";
import { client, type RequestOptions } from "./client";

export const albumQueries = {
  getAlbum(albumId?: UUID, opts?: RequestOptions) {
    return {
      enabled: !!albumId,
      queryKey: ["album", albumId],
      queryFn: ({ signal }: { signal?: AbortSignal }) =>
        client.get<undefined, Album>(`/albums/${albumId}`, { ...opts, signal }),
    };
  },

  paginateAlbums(
    artistId?: UUID,
    opts?: RequestOptions,
  ): UseInfiniteQueryOptions<
    Page<Album>,
    Error,
    InfiniteData<Page<Album>>,
    readonly unknown[],
    unknown
  > {
    return {
      enabled: !!artistId,
      queryKey: ["albums", artistId],
      initialPageParam: 1,
      getNextPageParam: (lastPage) => {
        if (!lastPage) return null;
        const nextPage = lastPage.pageNumber + 1;
        if (nextPage > lastPage.totalPages) return null;
        return nextPage;
      },
      queryFn: ({ pageParam, signal }) =>
        client.get<undefined, Page<Album>>(`/artists/${artistId}/albums`, {
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

export const albumApi = {
  getAlbum(albumId: UUID, opts?: RequestOptions) {
    return queryClient.ensureQueryData<Album>(
      albumQueries.getAlbum(albumId, opts),
    );
  },

  paginateAlbums(artistId: UUID, opts?: RequestOptions) {
    return ensureAutomaticInfiniteQueryData<Album>(
      albumQueries.paginateAlbums(artistId, opts),
    );
  },
};
