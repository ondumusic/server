import { useAutomaticInfiniteQuery } from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistAlbumsQuery({ albumArtistId }, opts = {}) {
  return useAutomaticInfiniteQuery(
    {
      path: `/artists/${albumArtistId}/albums`,
      queryKey: ["albumList", albumArtistId],
    },
    opts,
  );
}
