import { type PropsWithChildren, useCallback } from "react";
import { Loading } from "../../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { usePlayer } from "../../hooks/usePlayer";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import { useArtists } from "../../library";
import type { Artist, UUID } from "../../types";
import { ArtistRow } from "./ArtistRow";

function isArtist(artist: Artist, artistId: string): boolean {
  return artist.id === artistId || artist.slug === artistId;
}

export function Artists({
  artistId,
  onChange,
  onSubmit,
}: PropsWithChildren<{
  artistId?: UUID;
  onChange?: (artist: Artist) => void;
  onSubmit?: (artist: Artist) => void;
}>) {
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const { data: listItems, loading: isLoading } = useArtists();
  const { showToast } = useToast();

  const handleTypeMatch = useCallback((item: Artist, query: string) => {
    const matcher = new RegExp(`^${query.replace(/\s+/g, "")}`, "iu");
    const name = item.name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/\s+/g, "");

    return name.match(matcher) !== null;
  }, []);

  const handleChange = useCallback(
    (selectedIds: Set<string>) => {
      const artist = listItems.find((artist) => selectedIds.has(artist.id));
      if (!artist) return;

      if (typeof onChange === "function") {
        onChange(artist);
      }
    },
    [listItems, onChange],
  );

  const handleContextMenu = useCallback(
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

            showToast({
              message: i18next.t("toast.addedArtistToPlayNow", {
                defaultValue: "Playing {{ artistName }}",
                artistName: artist.name,
              }),
            });
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

            showToast({
              message: i18next.t("toast.addedArtistToPlayShuffled", {
                defaultValue: "Shuffling {{ artistName }}",
                artistName: artist.name,
              }),
            });
          },
        },
      ];
    },
    [listItems, userConfirmQueueReplace, populateUpNext, showToast],
  );

  const handleDoubleClick = useCallback(
    async (artist: Artist) => {
      if (typeof onSubmit === "function") {
        onSubmit(artist);
      }
    },
    [onSubmit],
  );

  const handleSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      const artist = listItems.find((artist) => selectedIds.has(artist.id));
      if (!artist) return;
      handleDoubleClick(artist);
    },
    [listItems, handleDoubleClick],
  );

  const renderItem = useCallback(
    (artist: Artist, state: ListItemState) => (
      <ArtistRow isSelected={state.isSelected} artist={artist} />
    ),
    [],
  );

  if (isLoading) return <Loading />;

  const currentArtist = artistId
    ? listItems.find((artist) => isArtist(artist, artistId))
    : undefined;

  return (
    <SelectableList<Artist>
      multiple={false}
      items={listItems}
      paddingTop={10}
      paddingBottom={10}
      defaultFocusId={currentArtist?.id}
      onTypeMatch={handleTypeMatch}
      defaultFocusType="center"
      selectedIds={currentArtist ? new Set([currentArtist.id]) : new Set([])}
      onContextMenu={handleContextMenu}
      onChange={handleChange}
      onSubmit={handleSubmit}
      onDoubleClick={handleDoubleClick}
      renderItem={renderItem}
    />
  );
}
