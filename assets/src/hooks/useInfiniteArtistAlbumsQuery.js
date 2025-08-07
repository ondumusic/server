import { useAutomaticInfiniteQuery } from "./useAutomaticInfiniteQuery";

export function useInfiniteArtistAlbumsQuery({ artistId }) {
  return useAutomaticInfiniteQuery({
    path: `/artists/${artistId}/albums`,
    queryKey: ["albumList", artistId],
  });
}
