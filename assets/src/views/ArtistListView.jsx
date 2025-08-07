import { useParams } from "react-router";

import { ArtistListItem } from "../components/ArtistListItem";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import { paginatedMap } from "../utils/paginatedMap";

export function ArtistListView() {
  const { artistId } = useParams();
  const { isFetching, hasFirstPage, isCompleted, data, error } =
    useInfiniteArtistsQuery();

  if (isFetching && !hasFirstPage) return "Loading...";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <ul>
      {paginatedMap(data, (artist) => (
        <ArtistListItem
          key={artist.id}
          isSelected={artistId === artist.id}
          scrollIntoView={isCompleted}
          artist={artist}
        />
      ))}
    </ul>
  );
}
