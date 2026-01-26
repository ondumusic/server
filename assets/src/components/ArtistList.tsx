import { useNavigate } from "@tanstack/react-router";
import { type PropsWithChildren, useCallback, useMemo } from "react";
import { ArtistListItem } from "../components/ArtistListItem";
import { Loading } from "../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import type { Artist, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

function isArtist(artist: Artist, artistId: string): boolean {
  return artist.id === artistId || artist.slug === artistId;
}

export function ArtistList({
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

  const listItems = useMemo(
    () => paginatedMap<Artist, Artist>(data, (artist) => artist),
    [data],
  );

  const onTypeMatch = useCallback((item: Artist, query: string) => {
    const matcher = new RegExp(`^${query.replace(/\s+/g, "")}`, "iu");
    const name = item.name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/\s+/g, "");

    return name.match(matcher) !== null;
  }, []);

  const onChange = useCallback(
    (selectedIds: Set<string>) => {
      const artist = listItems.find((artist) => selectedIds.has(artist.id));
      if (artist)
        navigate({
          to: `/artists/${artist.slug}`,
          params: { artistId: artist.id },
        });
    },
    [listItems, navigate],
  );

  const renderItem = useCallback(
    (artist: Artist, state: ListItemState) => (
      <ArtistListItem isSelected={state.isSelected} artist={artist} />
    ),
    [],
  );

  if (!hasFirstPage) return <Loading />;

  const currentArtist = artistId
    ? listItems.find((artist) => isArtist(artist, artistId))
    : undefined;

  return (
    <SelectableList<Artist>
      multiple={false}
      items={listItems}
      defaultFocusId={currentArtist?.id}
      onTypeMatch={onTypeMatch}
      defaultFocusType="center"
      selectedIds={currentArtist ? new Set([currentArtist.id]) : new Set([])}
      onContextMenu={() => []}
      onChange={onChange}
      renderItem={renderItem}
    />
  );
}
