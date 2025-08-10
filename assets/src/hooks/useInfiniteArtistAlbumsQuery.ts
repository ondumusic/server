import type { Album, UUID } from "../types";
import {
  type Options,
  useAutomaticInfiniteQuery,
} from "./useAutomaticInfiniteQuery";

interface Params {
  albumArtistId: UUID;
}

export function useInfiniteArtistAlbumsQuery(
  { albumArtistId }: Params,
  opts: Options = {},
) {
  return useAutomaticInfiniteQuery<Album>(
    {
      path: `/artists/${albumArtistId}/albums`,
      queryKey: ["albumList", albumArtistId],
    },
    opts,
  );
}
