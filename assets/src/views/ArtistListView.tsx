import { useParams } from "react-router";

import { ArtistListItem } from "../components/ArtistListItem";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { Artist, UUID } from "../types";
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
      {paginatedMap<Artist>(data, (artist) => (
        <ArtistListItem
          key={artist.id}
          isSelected={artistId === artist.id || artistId === artist.slug}
          scrollIntoView={isCompleted}
          artist={artist}
        />
      ))}
    </ul>
  );
}
