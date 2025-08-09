import { useParams } from "react-router";

import { ArtistListItem } from "../components/ArtistListItem";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import { paginatedMap } from "../utils/paginatedMap";

export function ArtistListView() {
  const { albumArtistId } = useParams();
  const { isFetching, hasFirstPage, isCompleted, data, error } =
    useInfiniteArtistsQuery();

  if (isFetching && !hasFirstPage) return "Loading...";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <ul>
      {paginatedMap(data, (albumArtist) => (
        <ArtistListItem
          key={albumArtist.id}
          isSelected={
            albumArtistId === albumArtist.id ||
            albumArtistId === albumArtist.slug
          }
          scrollIntoView={isCompleted}
          albumArtist={albumArtist}
        />
      ))}
    </ul>
  );
}
