import { useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { api } from "../services/api";
import type { Artist, UUID } from "../types";

interface Params {
  artistId: UUID;
}

export interface Options {
  enabled?: boolean;
  suspense?: boolean;
}

type Request = undefined;
type Response = Artist;

export function useArtistQuery({ artistId }: Params, opts: Options) {
  const enabled = !!opts.enabled;
  const queryFn =
    enabled && opts.suspense === true ? useSuspenseQuery : useQuery;

  return queryFn({
    queryKey: ["getArtist", artistId],
    queryFn: () => api.get<Request, Response>(`/artists/${artistId}`),
    enabled,
  });
}
