import type { Album, UUID } from "../types";
import {
  type Options,
  useAutomaticInfiniteQuery,
} from "./useAutomaticInfiniteQuery";

interface Params {
  artistId?: UUID;
}

import { albumQueries } from "../api";

export function useInfiniteArtistAlbumsQuery(
  { artistId }: Params,
  opts: Options<Album> = {},
) {
  return useAutomaticInfiniteQuery<Album>(
    albumQueries.paginateAlbums(artistId),
    opts,
  );
}
