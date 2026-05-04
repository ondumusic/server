import { createFileRoute, Navigate } from "@tanstack/react-router";
import { useCallback, useMemo, useState } from "react";
import { EmptyView } from "../../components/EmptyView";
import { Loading } from "../../components/Loading";
import { type ListItem, PlaylistItem } from "../../components/PlaylistItem";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import type { ContextMenuItem } from "../../hooks/useContextMenu";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistMutations } from "../../hooks/usePlaylistMutations";
import { useQueue } from "../../hooks/useQueue";
import i18next from "../../i18next";
import { queryTracksByIds, usePlaylist, usePlaylistItems } from "../../library";
import type { Track, UUID } from "../../types";
import { applyPending } from "../../utils/playlistPositions";

export const Route = createFileRoute("/_authenticated/playlists/$playlistId")({
  staticData: { view: "playlists" as const },
  component: PlaylistsDetail,
});

type Params = {
  playlistId: UUID;
};

function PlaylistsDetail() {
  const { playlistId } = Route.useParams() as Params;
  const [selectedItemIds, setSelectedItemIds] = useState<Set<UUID>>(
    new Set([]),
  );
  const { data: playlist, loading } = usePlaylist(playlistId);
  const { data: items, loading: loadingItems } = usePlaylistItems(playlistId);
  const { reorder, addTracks, removeItems, pending } = usePlaylistMutations(
    playlistId,
    items,
  );
  const { enqueueAndPlay, enqueueNext, enqueueAfter, userConfirmQueueReplace } =
    usePlayer();

  const { currentTrack } = useQueue();
  const currentItems = useMemo(
    () => applyPending(items, pending),
    [items, pending],
  );

  const renderItem = useCallback(
    (item: ListItem, state: ListItemState) => {
      let isPlaying = false;
      if (item.type === "track") {
        isPlaying = item.track?.id === currentTrack?.id;
      }

      return (
        <PlaylistItem
          item={item}
          isDragging={state.isDragging}
          isPlaying={isPlaying}
          isSelected={state.isSelected}
        />
      );
    },
    [currentTrack],
  );

  const onSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;

      const selectedTracks = currentItems
        .filter((item) => selectedIds.has(item.id))
        .map((item) => item.track as Track);

      if (selectedTracks.length === 1) {
        const selectedTrack = selectedTracks[0];

        // The default behaviour we want is to add all tracks from the same
        // playlist to the queue and start playback at the selected track.
        const playlistTracks = currentItems.map((item) => item.track as Track);
        enqueueAndPlay(playlistTracks, selectedTrack);
      } else {
        enqueueAndPlay(selectedTracks);
      }
    },
    [currentItems, enqueueAndPlay, userConfirmQueueReplace],
  );

  const onDoubleClick = useCallback(
    async (item: ListItem) => {
      if (item.type !== "track") return;
      if (!(await userConfirmQueueReplace())) return;

      // The default behaviour we want is to add all tracks from the same
      // playlist to the queue and start playback at the selected track.
      const playlistTracks = currentItems.map((item) => item.track as Track);
      enqueueAndPlay(playlistTracks, item.track);
    },
    [currentItems, enqueueAndPlay, userConfirmQueueReplace],
  );

  const onChange = useCallback((selectedIds: Set<UUID>) => {
    setSelectedItemIds(selectedIds);
  }, []);

  const onDelete = useCallback(
    (itemIds: Set<UUID>) => {
      removeItems(Array.from(itemIds));
    },
    [removeItems],
  );

  const onDrop = useCallback(
    (selectedIds: Set<UUID>, insertAtIndex: number, sourceListId: string) => {
      setSelectedItemIds(new Set([]));
      try {
        if (sourceListId === "upNext") {
          const trackIds = [...selectedIds].map((queueId) => {
            return queueId.split("/").shift() as UUID;
          });

          queryTracksByIds(trackIds).then((tracks) =>
            addTracks(tracks, insertAtIndex),
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

  const onContextMenu = useCallback(
    (selectedIds: Set<string>): ContextMenuItem[] => {
      if (selectedIds.size === 0) {
        return [];
      }

      const tracks = currentItems
        .filter((item) => selectedIds.has(item.id))
        .map((item) => item.track as Track);
      if (!tracks) return [];

      return [
        {
          type: "item",
          key: "play_next",
          label: i18next.t("contextMenu.playNext", {
            defaultValue: "Play Next",
            count: tracks.length,
          }),
          onClick() {
            enqueueNext(tracks);
          },
        },
        {
          type: "item",
          key: "play_after",
          label: i18next.t("contextMenu.playAfter", {
            defaultValue: "Play After",
            count: tracks.length,
          }),
          onClick() {
            enqueueAfter(tracks);
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
            count: tracks.length,
          }),
          onClick() {
            onDelete(selectedIds);
          },
        },
      ];
    },
    [currentItems, onDelete, enqueueNext, enqueueAfter],
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

  if (loading || loadingItems) {
    return <Loading />;
  }

  if (!playlist) {
    return <Navigate to="/playlists" />;
  }

  if (playlist.isFolder) {
    // PlaylistFolderIcon
    // import { PlaylistFolderIcon } from "../../components/icons/PlaylistFolderIcon";
    return <EmptyView message={playlist.name} />;
  }

  return (
    <div className="relative h-full mx-4 lg:mx-8">
      <SelectableList<ListItem>
        id="playlist"
        multiple
        allowDrag
        allowDropFrom={["playlist", "upNext"]}
        dropTargetClass="bg-blue-500"
        items={listItems}
        selectedIds={selectedItemIds}
        onChange={onChange}
        onDelete={onDelete}
        onDrop={onDrop}
        onSubmit={onSubmit}
        onContextMenu={onContextMenu}
        onDoubleClick={onDoubleClick}
        renderItem={renderItem}
      />

      {currentItems.length === 0 && (
        <div className="absolute top-0 left-0 right-0 bottom-0 pointer-events-none">
          <EmptyView
            message={i18next.t("playlist.emptyPlaylist", {
              defaultValue: "There are no tracks in this playlist yet.",
            })}
          />
        </div>
      )}
    </div>
  );
}
