import { useParams } from "react-router";

import { ArtistListItem } from "../components/ArtistListItem";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { AlbumArtist, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

type Params = { artistId: UUID };

export function ArtistListView() {
  const { artistId } = useParams() as Params;
  const { isFetching, hasFirstPage, isCompleted, data, error } =
    useInfiniteArtistsQuery();

  if (isFetching && !hasFirstPage) return "Loading...";
  if (error) throw error;

  return (
    <ul>
      {paginatedMap<AlbumArtist>(data, (albumArtist) => (
        <ArtistListItem
          key={albumArtist.id}
          isSelected={
            artistId === albumArtist.id || artistId === albumArtist.slug
          }
          scrollIntoView={isCompleted}
          albumArtist={albumArtist}
        />
      ))}
    </ul>
  );
}
