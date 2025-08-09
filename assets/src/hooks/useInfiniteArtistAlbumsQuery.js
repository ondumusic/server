import { useAutomaticInfiniteQuery } from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistAlbumsQuery({ albumArtistId }) {
  return useAutomaticInfiniteQuery({
    path: `/artists/${albumArtistId}/albums`,
    queryKey: ["albumList", albumArtistId],
  });
}
