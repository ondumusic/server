import { useParams } from "react-router";
import { ArtistListItem } from "../components/ArtistListItem";
import { Loading } from "../components/Loading";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { Artist, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

type Params = { artistId: UUID };

function isArtist(artist: Artist, artistId: string): boolean {
  return artist.id === artistId || artist.slug === artistId;
}

export function ArtistListView() {
  const { artistId } = useParams() as Params;
  const suspendUntil = artistId
    ? (entry: Artist) => isArtist(entry, artistId)
    : undefined;

  const { hasFirstPage, hasItem, isCompleted, data } = useInfiniteArtistsQuery({
    suspense: true,
    suspendUntil,
  });

  if (!hasFirstPage) return <Loading />;

  return (
    <ul>
      {paginatedMap<Artist>(data, (artist) => (
        <ArtistListItem
          key={artist.id}
          isSelected={isArtist(artist, artistId)}
          scrollIntoView={hasItem === true || isCompleted}
          artist={artist}
        />
      ))}
    </ul>
  );
}
