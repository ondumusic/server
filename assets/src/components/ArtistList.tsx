import { useNavigate } from "@tanstack/react-router";
import { type PropsWithChildren, useCallback, useMemo } from "react";
import { ArtistListItem } from "../components/ArtistListItem";
import { Loading } from "../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import { usePlayer } from "../hooks/usePlayer";
import i18next from "../i18next";
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
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();

  const {
    hasItem: hasArtist,
    hasFirstPage,
    data,
  } = useInfiniteArtistsQuery({
    matchItem: artistId
      ? (entry: Artist) => isArtist(entry, artistId)
      : undefined,
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

  const onContextMenu = useCallback(
    (selectedIds: Set<string>) => {
      const artist = listItems.find((artist) => selectedIds.has(artist.id));
      if (!artist) return [];

      return [
        {
          type: "item",
          key: "play_next",
          label: i18next.t("contextMenu.playArtist", {
            defaultValue: 'Play "{{ artist }}"',
            artist: artist.name,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ artistId: artist.id });
          },
        },
        {
          type: "item",
          key: "play_after",
          label: i18next.t("contextMenu.shuffleArtist", {
            defaultValue: 'Shuffle "{{ artist }}"',
            artist: artist.name,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ artistId: artist.id, random: true });
          },
        },
      ];
    },
    [listItems, userConfirmQueueReplace, populateUpNext],
  );

  const onDoubleClick = useCallback(
    async (artist: Artist) => {
      if (!(await userConfirmQueueReplace())) return;
      populateUpNext({ artistId: artist.id });
    },
    [userConfirmQueueReplace, populateUpNext],
  );

  const onSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;
      const artist = listItems.find((artist) => selectedIds.has(artist.id));
      if (!artist) return;
      populateUpNext({ artistId: artist.id });
    },
    [listItems, userConfirmQueueReplace, populateUpNext],
  );

  const renderItem = useCallback(
    (artist: Artist, state: ListItemState) => (
      <ArtistListItem isSelected={state.isSelected} artist={artist} />
    ),
    [],
  );

  if ((artistId && !hasArtist) || !hasFirstPage) return <Loading />;

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
      onContextMenu={onContextMenu}
      onChange={onChange}
      onSubmit={onSubmit}
      onDoubleClick={onDoubleClick}
      renderItem={renderItem}
    />
  );
}
