import { useParams } from "react-router";

import { ArtistListItem } from "../components/ArtistListItem";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { AlbumArtist, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

type Params = { albumArtistId: UUID };

export function ArtistListView() {
  const { albumArtistId } = useParams() as Params;
  const { isFetching, hasFirstPage, isCompleted, data, error } =
    useInfiniteArtistsQuery();

  if (isFetching && !hasFirstPage) return "Loading...";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <ul>
      {paginatedMap<AlbumArtist>(data, (albumArtist) => (
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
