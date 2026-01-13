import { useNavigate, useParams } from "react-router";
import { ArtistListItem } from "../components/ArtistListItem";
import { Loading } from "../components/Loading";
import { SelectableList } from "../components/SelectableList";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { Artist, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

type Params = { artistId: UUID };

function isArtist(artist: Artist, artistId: string): boolean {
  return artist.id === artistId || artist.slug === artistId;
}

export function ArtistListView() {
  const { artistId } = useParams() as Params;
  const navigate = useNavigate();

  const suspendUntil = artistId
    ? (entry: Artist) => isArtist(entry, artistId)
    : undefined;

  const { hasFirstPage, data } = useInfiniteArtistsQuery({
    suspense: true,
    suspendUntil,
  });

  if (!hasFirstPage) return <Loading />;

  const listItems = paginatedMap<Artist, Artist>(data, (artist) => artist);
  const currentArtist = listItems.find((artist) => isArtist(artist, artistId));

  return (
    <SelectableList<Artist>
      multiple={false}
      items={listItems}
      defaultFocusId={currentArtist?.id}
      defaultFocusType="center"
      selectedIds={currentArtist ? new Set([currentArtist.id]) : new Set([])}
      onChange={(selectedIds) => {
        const artist = listItems.find((artist) => selectedIds.has(artist.id));
        if (artist) navigate(`/artists/${artist.slug}`);
      }}
      renderItem={(artist, state) => (
        <ArtistListItem isSelected={state.isSelected} artist={artist} />
      )}
    />
  );
}
