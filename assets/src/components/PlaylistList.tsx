import { useNavigate } from "@tanstack/react-router";
import { type PropsWithChildren, useCallback } from "react";
import { Loading } from "../components/Loading";
import { PlaylistListItem } from "../components/PlaylistListItem";
import {
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import { usePlayer } from "../hooks/usePlayer";
import i18next from "../i18next";
import { usePlaylists } from "../library";
import type { Playlist, UUID } from "../types";

function isPlaylist(playlist: Playlist, playlistId: string): boolean {
  return playlist.id === playlistId;
}

// https://claude.ai/chat/3cd47d5e-1bb8-4f4d-8889-df5aba58583d

export function PlaylistList({
  playlistId,
}: PropsWithChildren<{
  playlistId?: UUID;
}>) {
  const navigate = useNavigate();
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const { data: listItems, loading: isLoading } = usePlaylists();

  const onTypeMatch = useCallback((item: Playlist, query: string) => {
    const matcher = new RegExp(`^${query.replace(/\s+/g, "")}`, "iu");
    const name = item.name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/\s+/g, "");

    return name.match(matcher) !== null;
  }, []);

  const onChange = useCallback(
    (selectedIds: Set<string>) => {
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return;
      if (playlist.isFolder) return;
      navigate({
        to: `/playlists/${playlist.id}`,
        params: { playlistId: playlist.id },
      });
    },
    [listItems, navigate],
  );

  const onContextMenu = useCallback(
    (selectedIds: Set<string>) => {
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return [];
      if (playlist.isFolder) return [];

      return [
        {
          type: "item",
          key: "play_next",
          label: i18next.t("contextMenu.playPlaylist", {
            defaultValue: 'Play "{{ playlist }}"',
            playlist: playlist.name,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ playlistId: playlist.id });
          },
        },
        {
          type: "item",
          key: "play_after",
          label: i18next.t("contextMenu.shufflePlaylist", {
            defaultValue: 'Shuffle "{{ playlist }}"',
            playlist: playlist.name,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ playlistId: playlist.id, random: true });
          },
        },
      ];
    },
    [listItems, userConfirmQueueReplace, populateUpNext],
  );

  const onDoubleClick = useCallback(
    async (playlist: Playlist) => {
      if (playlist.isFolder) return;
      if (!(await userConfirmQueueReplace())) return;
      populateUpNext({ playlistId: playlist.id });
    },
    [userConfirmQueueReplace, populateUpNext],
  );

  const onSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return;
      populateUpNext({ playlistId: playlist.id });
    },
    [listItems, userConfirmQueueReplace, populateUpNext],
  );

  const renderItem = useCallback(
    (playlist: Playlist, state: ListItemState) => (
      <PlaylistListItem isSelected={state.isSelected} playlist={playlist} />
    ),
    [],
  );

  if (isLoading) return <Loading />;

  const currentPlaylist = playlistId
    ? listItems.find((playlist) => isPlaylist(playlist, playlistId))
    : undefined;

  return (
    <SelectableList<Playlist>
      multiple={false}
      items={listItems}
      paddingTop={10}
      paddingBottom={10}
      defaultFocusId={currentPlaylist?.id}
      onTypeMatch={onTypeMatch}
      defaultFocusType="center"
      selectedIds={
        currentPlaylist ? new Set([currentPlaylist.id]) : new Set([])
      }
      onContextMenu={onContextMenu}
      onChange={onChange}
      onSubmit={onSubmit}
      onDoubleClick={onDoubleClick}
      renderItem={renderItem}
    />
  );
}
