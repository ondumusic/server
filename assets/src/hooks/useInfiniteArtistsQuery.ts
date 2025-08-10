import type { AlbumArtist } from "../types";
import { useAutomaticInfiniteQuery } from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistsQuery() {
  return useAutomaticInfiniteQuery<AlbumArtist>({
    path: "/artists",
    queryKey: ["artistList"],
  });
}
