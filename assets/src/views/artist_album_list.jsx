import { useInfiniteQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { useParams } from "react-router";

export function ArtistAlbumList() {
  const params = useParams();

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
      fetch(`/api/artists/${params.artistId}/albums?page=${pageParam}`).then(
        (res) => res.json(),
      ),
  });

  useEffect(() => {
    if (hasNextPage && !isFetchingNextPage && !isFetching && !error) {
      fetchNextPage();
    }
  }, [isFetching, error, hasNextPage, isFetchingNextPage, fetchNextPage]);

  if (isFetching && !data) return "";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <div class="space-y-8 mx-8">
      {data.pages.map((page) =>
        page.entries.map((album) => (
          <div key={album.id} class="flex w-full">
            <div class="w-1/4 flex-shrink-0">
              <p>{album.name}</p>
            </div>
            <div class="w-3/4">
              <ul>
                {album.songs.map((song) => (
                  <li key={song.id}>
                    {song.track || 0}. {song.name}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        )),
      )}
    </div>
  );
}
