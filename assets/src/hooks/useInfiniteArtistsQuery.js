import { useAutomaticInfiniteQuery } from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistsQuery() {
  return useAutomaticInfiniteQuery({
    path: "/artists",
    queryKey: ["artistList"],
  });
}
