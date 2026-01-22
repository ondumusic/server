import { useNavigate } from "@tanstack/react-router";
import type { PropsWithChildren } from "react";
import { ArtistListItem } from "../components/ArtistListItem";
import { Loading } from "../components/Loading";
import { SelectableList } from "../components/SelectableList";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { Artist, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

function isArtist(artist: Artist, artistId: string): boolean {
  return artist.id === artistId || artist.slug === artistId;
}

export function ArtistListView({
  artistId,
}: PropsWithChildren<{
  artistId?: UUID;
}>) {
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
  const currentArtist = artistId
    ? listItems.find((artist) => isArtist(artist, artistId))
    : undefined;

  return (
    <SelectableList<Artist>
      multiple={false}
      items={listItems}
      defaultFocusId={currentArtist?.id}
      defaultFocusType="center"
      selectedIds={currentArtist ? new Set([currentArtist.id]) : new Set([])}
      onContextMenu={() => []}
      onChange={(selectedIds) => {
        const artist = listItems.find((artist) => selectedIds.has(artist.id));
        if (artist)
          navigate({
            to: `/artists/${artist.slug}`,
            params: { artistId: artist.id },
          });
      }}
      renderItem={(artist, state) => (
        <ArtistListItem isSelected={state.isSelected} artist={artist} />
      )}
    />
  );
}
