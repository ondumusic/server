import { useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { albumQueries } from "../api";
import type { Album, UUID } from "../types";

interface Params {
  albumId?: UUID;
}

export interface Options {
  enabled?: boolean;
  suspense?: boolean;
}

export function useAlbumQuery({ albumId }: Params, opts: Options) {
  const enabled = !!opts?.enabled;
  const queryFn =
    enabled && opts?.suspense === true ? useSuspenseQuery : useQuery;
  return queryFn<Album>({
    ...albumQueries.getAlbum(albumId),
    enabled,
  });
}
