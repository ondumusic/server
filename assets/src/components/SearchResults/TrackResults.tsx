import { useNavigate } from "@tanstack/react-router";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { ContextMenuItem } from "../../hooks/useContextMenu";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistPicker } from "../../hooks/usePlaylistPicker";
import { useQueue } from "../../hooks/useQueue";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import { queryAlbum, queryArtist } from "../../library";
import type { Track, UUID } from "../../types";
import { appendTracksToPlaylist } from "../../utils/appendTracksToPlaylist";
import { type ListItemState, SelectableList } from "../SelectableList";
import { TrackRow } from "../Tracks";
import type { TrackItem } from "./types";

interface Props {
  tracks: Track[];
}

export function TrackResults({ tracks }: Props) {
  const navigate = useNavigate();
  const { showToast } = useToast();
  const { showPlaylistPicker, getMostRecentPlaylist } = usePlaylistPicker();
  const { enqueueAndPlay, enqueueNext, enqueueAfter, userConfirmQueueReplace } =
    usePlayer();
  const { currentTrack } = useQueue();
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  // Clears the selection when the results change.
  // biome-ignore lint/correctness/useExhaustiveDependencies(tracks): only used to trigger a reset
  useEffect(() => {
    setSelectedIds(new Set());
  }, [tracks]);

  // Build the list items
  const listItems = useMemo(() => {
    const lastIndex = tracks.length - 1;
    const items: TrackItem[] = [];

    for (const [index, track] of tracks.entries()) {
      const isLast = index === lastIndex;

      items.push({
        id: track.id,
        track,
        isLast,
      });
    }

    return items;
  }, [tracks]);

  const handleDoubleClick = useCallback(
    async (item: TrackItem) => {
      if (!(await userConfirmQueueReplace())) return;
      enqueueAndPlay([{ track: item.track }]);
    },
    [enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleSubmit = useCallback(
    async (ids: Set<string>) => {
      const selected = tracks.filter((track) => ids.has(track.id));
      if (!selected.length) return;
      if (!(await userConfirmQueueReplace())) return;
      enqueueAndPlay(selected.map((track) => ({ track })));
    },
    [tracks, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleContextMenu = useCallback(
    async (ids: Set<string>): Promise<ContextMenuItem[]> => {
      const recentPlaylist = getMostRecentPlaylist();
      const selectedTracks = tracks.filter((track) => ids.has(track.id));
      if (selectedTracks.length === 0) return [];

      const playlistActions = [
        {
          type: "item",
          key: "add_to_playlist",
          label: i18next.t("contextMenu.addToPlaylist", {
            defaultValue: "Add To Playlist...",
            count: selectedTracks.length,
          }),
          onClick: async () => {
            const playlist = await showPlaylistPicker();
            if (playlist === false) return;
            await appendTracksToPlaylist(playlist.id, selectedTracks);
            showToast({
              link: `/playlists/${playlist.id}`,
              message: i18next.t("toast.addedToPlaylist", {
                defaultValue: "Added {{ count }} tracks to {{ playlistName }}",
                count: selectedTracks.length,
                playlistName: playlist.name,
              }),
            });
          },
        },
      ];

      if (recentPlaylist) {
        playlistActions.unshift({
          type: "item",
          key: "add_to_recent_playlist",
          label: i18next.t("contextMenu.addToRecentPlaylist", {
            defaultValue: "Add To {{ playlistName }}",
            playlistName: recentPlaylist.name,
          }),
          onClick: async () => {
            await appendTracksToPlaylist(
              recentPlaylist.id as UUID,
              selectedTracks,
            );
            showToast({
              link: `/playlists/${recentPlaylist.id}`,
              message: i18next.t("toast.addedToPlaylist", {
                defaultValue: "Added {{ count }} tracks to {{ playlistName }}",
                count: selectedTracks.length,
                playlistName: recentPlaylist.name,
              }),
            });
          },
        });
      }

      const gotoActions: ContextMenuItem[] = [];
      if (selectedTracks.length === 1) {
        const artist = await queryArtist(selectedTracks[0].albumArtistId);
        const album = await queryAlbum(selectedTracks[0].albumId);

        if (artist) {
          gotoActions.push({
            type: "item",
            key: "goto_artist",
            label: i18next.t("contextMenu.gotoArtist", {
              defaultValue: "Go to Artist",
            }),
            onClick: async () => {
              navigate({
                to: `/artists/${artist.slug}`,
              });
            },
          });
        }

        if (artist && album) {
          gotoActions.push({
            type: "item",
            key: "goto_album",
            label: i18next.t("contextMenu.gotoAlbum", {
              defaultValue: "Go to Album",
            }),
            onClick: async () => {
              navigate({
                to: `/artists/${artist.slug}/${album.slug}`,
              });
            },
          });
        }

        if (gotoActions.length) {
          gotoActions.push({
            type: "divider" as const,
            key: "goto_actions",
          });
        }
      }

      return [
        {
          type: "item",
          key: "play_next",
          label: i18next.t("contextMenu.playNext", {
            defaultValue: "Play Next",
          }),
          onClick() {
            enqueueNext(selectedTracks.map((track) => ({ track })));

            showToast({
              message: i18next.t("toast.addedToPlayNext", {
                defaultValue: "Added {{ count }} tracks to up next",
                count: selectedTracks.length,
              }),
            });
          },
        },
        {
          type: "item",
          key: "play_after",
          label: i18next.t("contextMenu.playAfter", {
            defaultValue: "Add To Queue",
          }),
          onClick() {
            enqueueAfter(selectedTracks.map((track) => ({ track })));

            showToast({
              message: i18next.t("toast.addedToPlayAfter", {
                defaultValue: "Added {{ count }} tracks to the queue",
                count: selectedTracks.length,
              }),
            });
          },
        },
        {
          type: "divider" as const,
          key: "queue_actions",
        },
        ...gotoActions,
        ...playlistActions,
      ];
    },
    [
      tracks,
      navigate,
      enqueueNext,
      enqueueAfter,
      showPlaylistPicker,
      getMostRecentPlaylist,
      showToast,
    ],
  );

  const renderItem = useCallback(
    (item: TrackItem, state: ListItemState) => (
      <TrackRow
        track={item.track}
        number={0}
        isSelected={state.isSelected}
        isPlaying={item.id === currentTrack?.id}
        isDragging={state.isDragging}
        isLastTrack={item.isLast}
        showNumber={false}
      />
    ),
    [currentTrack],
  );

  return (
    <SelectableList<TrackItem>
      id="searchTracks"
      multiple
      allowDrag
      allowDropFrom={[]}
      items={listItems}
      renderItem={renderItem}
      selectedIds={selectedIds}
      onChange={setSelectedIds}
      onSubmit={handleSubmit}
      onDoubleClick={handleDoubleClick}
      onContextMenu={handleContextMenu}
    />
  );
}
