import type { Album, UUID } from "../types";
import {
  type Options,
  useAutomaticInfiniteQuery,
} from "./useAutomaticInfiniteQuery";

interface Params {
  artistId: UUID;
}

export function useInfiniteArtistAlbumsQuery(
  { artistId }: Params,
  opts: Options = {},
) {
  return useAutomaticInfiniteQuery<Album>(
    {
      path: `/artists/${artistId}/albums`,
      queryKey: ["albumList", artistId],
    },
    opts,
  );
}
