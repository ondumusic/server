import {
  useInfiniteQuery,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { useEffect } from "react";
import { useParams } from "react-router";
import { ArtistAlbumListHeader } from "../components/ArtistAlbumListHeader";
import { ArtistAlbumListItem } from "../components/ArtistAlbumListItem";
import { api } from "../services/api";
import { paginatedMap } from "../utils/paginatedMap";

export function ArtistAlbumListView() {
  const _queryClient = useQueryClient();
  const params = useParams();

  const { isFetching: isFetchingArtist, data: dataArtist } = useQuery({
    queryKey: ["artist", params.artistId],
    queryFn: () => api.get(`/artists/${params.artistId}`),
  });

  const {
    error,
    data,
    fetchNextPage,
    hasNextPage,
    isFetching,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey: ["albumList", params.artistId],
    getNextPageParam: (lastPage, _page) => {
      const nextPage = lastPage.page_number + 1;
      if (nextPage > lastPage.total_pages) return null;
      return nextPage;
    },
    queryFn: ({ pageParam = 1 }) =>
      api.get(`/artists/${params.artistId}/albums`, { page: pageParam }),
  });

  useEffect(() => {
    if (hasNextPage && !isFetchingNextPage && !isFetching && !error) {
      fetchNextPage();
    }
  }, [isFetching, error, hasNextPage, isFetchingNextPage, fetchNextPage]);

  if (isFetching && !data) return "";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <div class="space-y-8 mx-8 my-8">
      {!isFetchingArtist ? <ArtistAlbumListHeader artist={dataArtist} /> : null}
      {paginatedMap(data, (album) => (
        <ArtistAlbumListItem key={album.id} album={album} />
      ))}
    </div>
  );
}
