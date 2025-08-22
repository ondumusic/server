import type { Artist } from "../types";
import {
  type Options,
  useAutomaticInfiniteQuery,
} from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistsQuery(opts: Options<Artist> = {}) {
  return useAutomaticInfiniteQuery<Artist>(
    {
      path: "/artists",
      queryKey: ["artistList"],
    },
    opts,
  );
}
