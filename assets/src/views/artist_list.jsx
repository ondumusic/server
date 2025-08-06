import { useInfiniteQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { Link } from "react-router";

export function ArtistListView() {
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
    queryFn: ({ pageParam = 1 }) =>
      fetch(`/api/artists?page=${pageParam}`).then((res) => res.json()),
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
      {data.pages.map((page) =>
        page.entries.map((artist) => (
          <li
            key={artist.id}
            class="whitespace-nowrap text-ellipsis max-w-full overflow-hidden"
          >
            <Link to={`/artist/${artist.id}`}>{artist.name}</Link>
          </li>
        )),
      )}
    </ul>
  );
}
