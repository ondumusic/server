import type { Artist } from "../types";
import { useAutomaticInfiniteQuery } from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistsQuery() {
  return useAutomaticInfiniteQuery<Artist>({
    path: "/artists",
    queryKey: ["artistList"],
  });
}
