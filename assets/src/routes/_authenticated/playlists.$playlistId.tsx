import { createFileRoute, Navigate } from "@tanstack/react-router";
import { useCallback, useMemo, useState } from "react";
import { Loading } from "../../components/Loading";
import { type ListItem, PlaylistItem } from "../../components/PlaylistItem";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistMutations } from "../../hooks/usePlaylistMutations";
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
  const {
    enqueueAndPlay,
    // enqueueNext,
    // enqueueAfter,
    // populateUpNext,
    userConfirmQueueReplace,
  } = usePlayer();

  const currentItems = useMemo(
    () => applyPending(items, pending),
    [items, pending],
  );

  const renderItem = useCallback((item: ListItem, state: ListItemState) => {
    return (
      <PlaylistItem
        item={item}
        isDragging={state.isDragging}
        isSelected={state.isSelected}
      />
    );
  }, []);

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
      results.unshift({
        id: "playlistHeader",
        type: "playlist",
        selectable: false,
        playlist,
      });
    }

    return results;
  }, [playlist, currentItems]);

  if (loading || loadingItems) {
    return <Loading />;
  }

  if (playlistId === "asd") {
    return <Navigate to="/playlists" />;
  }

  return (
    <div className="h-full mx-4 lg:mx-8">
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
        // onContextMenu={onContextMenu}
        onDoubleClick={onDoubleClick}
        renderItem={renderItem}
      />
    </div>
  );
}
