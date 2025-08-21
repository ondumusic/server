import { useParams } from "react-router";

import { ArtistListItem } from "../components/ArtistListItem";
import { Loading } from "../components/Loading";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { Artist, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

type Params = { artistId: UUID };

export function ArtistListView() {
  const { artistId } = useParams() as Params;
  const { isFetching, hasFirstPage, isCompleted, data, error } =
    useInfiniteArtistsQuery();

  let hasArtist = hasFirstPage && !artistId;
  if (hasFirstPage && artistId && data) {
    hasArtist = !!data.pages?.find(({ entries }) =>
      entries.find((entry) => entry.id === artistId || entry.slug === artistId),
    );
  }

  if (isFetching && !hasArtist) return <Loading />;
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
