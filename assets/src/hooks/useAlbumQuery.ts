import { useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { albumQueries } from "../api";
import type { Album, UUID } from "../types";

interface Params {
  albumId?: UUID;
}

export interface Options {
  suspense?: boolean;
}

export function useAlbumQuery({ albumId }: Params, opts?: Options) {
  const query = albumQueries.getAlbum(albumId);
  const queryFn =
    query.enabled !== false && opts?.suspense === true
      ? useSuspenseQuery
      : useQuery;

  return queryFn<Album>(query);
}
