import { useInfiniteQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { useParams } from "react-router";

import { ArtistListItem } from "../components/ArtistListItem";
import { api } from "../services/api";
import { paginatedMap } from "../utils/paginatedMap";

export function ArtistListView() {
  const params = useParams();

  const {
    error,
    data,
    fetchNextPage,
    hasNextPage,
    isFetching,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey: ["artistList"],
    getNextPageParam: (lastPage, _page) => {
      const nextPage = lastPage.page_number + 1;
      if (nextPage > lastPage.total_pages) return null;
      return nextPage;
    },
    queryFn: ({ pageParam = 1 }) => api.get("/artists", { page: pageParam }),
  });

  useEffect(() => {
    if (hasNextPage && !isFetchingNextPage && !isFetching && !error) {
      fetchNextPage();
    }
  }, [isFetching, error, hasNextPage, isFetchingNextPage, fetchNextPage]);

  if (isFetching && !data) return "Loading...";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <ul>
      {paginatedMap(data, (artist) => (
        <ArtistListItem
          key={artist.id}
          isSelected={params.artistId === artist.id}
          artist={artist}
        />
      ))}
    </ul>
  );
}
