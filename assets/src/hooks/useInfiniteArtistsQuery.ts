import { artistQueries } from "../api";
import type { Artist } from "../types";
import {
  type Options,
  useAutomaticInfiniteQuery,
} from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistsQuery(opts: Options<Artist> = {}) {
  return useAutomaticInfiniteQuery<Artist>(
    artistQueries.paginateArtists(),
    opts,
  );
}
