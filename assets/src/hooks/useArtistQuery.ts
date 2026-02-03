import { useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { artistQueries } from "../api";
import type { Artist, UUID } from "../types";

interface Props {
  artistId: UUID;
}

interface Options {
  enabled?: boolean;
  suspense?: boolean;
}

export function useArtistQuery({ artistId }: Props, opts: Options) {
  const enabled = !!opts.enabled;
  const queryFn =
    enabled && opts.suspense === true ? useSuspenseQuery : useQuery;

  return queryFn<Artist>({
    ...artistQueries.getArtist(artistId),
    enabled,
  });
}
