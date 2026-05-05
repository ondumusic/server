import { useCallback, useMemo, useState } from "react";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import type { ContextMenuItem } from "../../hooks/useContextMenu";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistMutations } from "../../hooks/usePlaylistMutations";
import { useQueue } from "../../hooks/useQueue";
import i18next from "../../i18next";
import { queryTracksByIds } from "../../library";
import type {
  PlaylistItem,
  Playlist as TPlaylist,
  Track,
  UUID,
} from "../../types";
import { applyPending } from "../../utils/playlistPositions";
import { PlaylistHeaderRow } from "./PlaylistHeaderRow";
import { PlaylistTrackRow } from "./PlaylistTrackRow";
import type { ListItem } from "./types";

interface Props {
  playlist: TPlaylist;
  items: PlaylistItem[];
}

export function Playlist({ playlist, items }: Props) {
  const playlistId = playlist.id;
  const [selectedItemIds, setSelectedItemIds] = useState<Set<UUID>>(
    new Set([]),
  );

  const { reorder, addTracks, removeItems, pending } = usePlaylistMutations(
    playlistId,
    items,
  );
  const { enqueueAndPlay, enqueueNext, enqueueAfter, userConfirmQueueReplace } =
    usePlayer();

  const { currentItem } = useQueue();
  const currentItems = useMemo(
    () => applyPending(items, pending),
    [items, pending],
  );

  const renderItem = useCallback(
    (item: ListItem, state: ListItemState) => {
      switch (item.type) {
        case "playlist":
          return <PlaylistHeaderRow item={item} />;
        case "track": {
          const isPlaying = item.item.id === currentItem?.meta?.playlistItemId;

          return (
            <PlaylistTrackRow
              item={item}
              isDragging={state.isDragging}
              isPlaying={isPlaying}
              isSelected={state.isSelected}
            />
          );
        }
      }
    },
    [currentItem],
  );

  const handleSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;

      const selectedItems = currentItems
        .filter((item) => selectedIds.has(item.id))
        .map((item) => ({
          track: item.track as Track,
          meta: {
            playlistItemId: item.id,
          },
        }));

      if (selectedItems.length === 1) {
        const item = selectedItems[0];

        // The default behaviour we want is to add all tracks from the same
        // playlist to the queue and start playback at the selected track.
        const queueItems = currentItems.map((item) => ({
          track: item.track as Track,
          meta: {
            playlistItemId: item.id,
          },
        }));

        const startWithItem = queueItems.find((queueItem) => {
          return queueItem.meta.playlistItemId === item.meta.playlistItemId;
        });

        enqueueAndPlay(queueItems, startWithItem);
      } else {
        enqueueAndPlay(selectedItems);
      }
    },
    [currentItems, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleDoubleClick = useCallback(
    async (item: ListItem) => {
      if (item.type !== "track") return;
      if (!(await userConfirmQueueReplace())) return;

      // The default behaviour we want is to add all tracks from the same
      // playlist to the queue and start playback at the selected track.
      const queueItems = currentItems.map((item) => ({
        track: item.track as Track,
        meta: {
          playlistItemId: item.id,
        },
      }));

      const startWithItem = queueItems.find((queueItem) => {
        return queueItem.meta.playlistItemId === item.item.id;
      });

      enqueueAndPlay(queueItems, startWithItem);
    },
    [currentItems, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleChange = useCallback((selectedIds: Set<UUID>) => {
    setSelectedItemIds(selectedIds);
  }, []);

  const handleDelete = useCallback(
    (itemIds: Set<UUID>) => {
      removeItems(Array.from(itemIds));
    },
    [removeItems],
  );

  const handleDrop = useCallback(
    (selectedIds: Set<UUID>, insertAtIndex: number, sourceListId: string) => {
      setSelectedItemIds(new Set([]));
      try {
        if (sourceListId === "upNext") {
          const trackIds = [...selectedIds].map((queueId) => {
            return queueId.split("/").shift() as UUID;
          });

          queryTracksByIds(trackIds).then((tracks) =>
            // insertAtIndex assumes the current item is already in the list
            // so we need to do -1 to make it appear in the right spot when
            // adding to Playlist from upNext
            addTracks(tracks, Math.max(0, insertAtIndex - 1)),
          );
          //.catch(showErrorToast);
        } else {
          reorder(selectedIds, insertAtIndex); //.catch(showErrorToast);
        }
      } catch (err) {
        console.log(err);
      }
    },
    [addTracks, reorder],
  );

  const handleContextMenu = useCallback(
    (selectedIds: Set<string>): ContextMenuItem[] => {
      if (selectedIds.size === 0) {
        return [];
      }

      const queueItems = currentItems
        .filter((item) => selectedIds.has(item.id))
        .map((item) => ({
          track: item.track as Track,
          meta: {
            playlistItemId: item.id,
          },
        }));
      if (!queueItems) return [];

      return [
        {
          type: "item",
          key: "play_next",
          label: i18next.t("contextMenu.playNext", {
            defaultValue: "Play Next",
            count: queueItems.length,
          }),
          onClick() {
            enqueueNext(queueItems);
          },
        },
        {
          type: "item",
          key: "play_after",
          label: i18next.t("contextMenu.playAfter", {
            defaultValue: "Add To Queue",
            count: queueItems.length,
          }),
          onClick() {
            enqueueAfter(queueItems);
          },
        },
        {
          type: "divider",
          key: "destructive",
        },
        {
          type: "item",
          key: "remove",
          danger: true,
          label: i18next.t("contextMenu.removeTracks", {
            defaultValue: "Remove {{ count }} tracks",
            count: queueItems.length,
          }),
          onClick() {
            handleDelete(selectedIds);
          },
        },
      ];
    },
    [currentItems, handleDelete, enqueueNext, enqueueAfter],
  );

  const listItems = useMemo(() => {
    let results: ListItem[] = [];
    if (currentItems?.length) {
      const trackCount = currentItems.length;

      results = currentItems.map((item, trackIndex) => {
        return {
          id: item.id,
          number: trackIndex + 1,
          type: "track",
          item,
          position: item.position,
          track: item.track as Track,
          lastTrack: trackIndex === trackCount - 1,
        };
      });
    }

    if (playlist) {
      const totalDuration = currentItems.reduce(
        (total, item) => total + (item?.track?.duration ?? 0),
        0,
      );

      results.unshift({
        id: "playlistHeader",
        type: "playlist",
        selectable: false,
        totalDuration,
        playlist,
      });
    }

    return results;
  }, [playlist, currentItems]);

  return (
    <SelectableList<ListItem>
      id="playlist"
      multiple
      allowDrag
      allowDropFrom={["playlist", "upNext"]}
      dropTargetClass="bg-blue-500"
      items={listItems}
      selectedIds={selectedItemIds}
      onChange={handleChange}
      onDelete={handleDelete}
      onDrop={handleDrop}
      onSubmit={handleSubmit}
      onContextMenu={handleContextMenu}
      onDoubleClick={handleDoubleClick}
      renderItem={renderItem}
    />
  );
}
