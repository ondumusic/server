import i18next from "i18next";
import {
  type DragEvent,
  type PropsWithChildren,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { Trans } from "react-i18next";
import {
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import { usePlaylistPicker } from "../hooks/usePlaylistPicker";
import { type QueueItem, useQueue } from "../hooks/useQueue";
import { useToast } from "../hooks/useToast";
import { queryPlaylistItemsByIds, queryTracksByIds } from "../library";
import type { Track, UUID } from "../types";
import { appendTracksToPlaylist } from "../utils/appendTracksToPlaylist";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";

type ListItem = QueueItem & {
  id: string;
  position: number;
};

const trackToQueueItem = (track: Track) => ({
  track,
});

export function UpNext({
  isVisible,
}: PropsWithChildren<{
  isVisible: boolean;
}>) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set([]),
  );
  const { showPlaylistPicker, getMostRecentPlaylist } = usePlaylistPicker();
  const { showToast } = useToast();
  const [height, setHeight] = useState<number>(0);
  const {
    queue,
    currentTrackIndex,
    removeFromQueue,
    skipToTrackIndex,
    clearNextTracks,
    addQueueAtIndex,
    addQueueAfter,
    rearrangeQueue,
  } = useQueue();

  const allowDropFrom = useMemo(
    () => ["upNext", "albumTracks", "playlist"],
    [],
  );

  useEffect(() => {
    if (!containerRef.current) return;
    if (!containerRef.current.parentNode) return;

    const observer = new ResizeObserver((elements) => {
      if (!containerRef.current) return;
      if (!containerRef.current.parentNode) return;
      const parentNode = containerRef.current.parentNode as HTMLElement;

      // Calculate how much space is available in the parentNode after removing
      // the height of our siblings.
      let availableHeight: number = parentNode.getBoundingClientRect().height;
      for (const element of elements) {
        if (element.target !== containerRef.current) {
          availableHeight -= element.contentRect.height;
        }
      }

      setHeight(Math.ceil(availableHeight));
    });

    for (const child of containerRef.current.parentNode.children) {
      observer.observe(child);
    }
    return () => observer.disconnect();
  }, []);

  const listItems: ListItem[] = useMemo(() => {
    return (
      queue
        .map((item, position) => ({
          ...item,
          position,
          // We need unique IDs for SelectableList, however we also support
          // having the same track multiple times. So we include the trackIndex
          // as part of the ID.
          id: [item.track.id, position].join("/"),
        }))
        // We only want to display upcoming items from the queue, as the rest
        // is considered "history".
        .filter((item) => item.position > currentTrackIndex)
    );
  }, [queue, currentTrackIndex]);

  const handleDragOver = useCallback((e: DragEvent) => {
    e.stopPropagation();
    e.preventDefault();
    e.dataTransfer.dropEffect = "copy";
  }, []);

  const handleDropEmpty = useCallback(
    (e: DragEvent) => {
      e.preventDefault();
      e.stopPropagation();

      try {
        const { sourceListId, itemIds } = JSON.parse(
          e.dataTransfer.getData("application/json"),
        );

        if (sourceListId === "playlist") {
          queryPlaylistItemsByIds(Array.from(itemIds))
            .then((items) =>
              items.map((item) => ({
                track: item.track as Track,
                meta: {
                  playlistItemId: item.id,
                },
              })),
            )
            .then(addQueueAfter);
        } else {
          queryTracksByIds(Array.from(itemIds))
            .then((tracks) => tracks.map(trackToQueueItem))
            .then(addQueueAfter);
        }
      } catch (_error) {
        return;
      }
    },
    [addQueueAfter],
  );

  const handleChange = useCallback(
    (itemIds: Set<string>) => setSelectedTrackIds(itemIds),
    [],
  );

  const handleDelete = useCallback(
    (itemIds: Set<string>) => {
      const selectedItems = listItems.filter((item) => itemIds.has(item.id));
      const trackIndexes = selectedItems.map((item) => item.position);
      if (trackIndexes.length !== 0) {
        removeFromQueue(trackIndexes);
      }
    },
    [listItems, removeFromQueue],
  );

  const handleContextMenu = useCallback(
    (selectedIds: Set<string>) => {
      const recentPlaylist = getMostRecentPlaylist();

      const selectedTracks = listItems
        .filter((item) => selectedIds.has(item.id))
        .map((item) => item.track);
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
                defaultValue: "Add {{ count }} tracks to {{ playlistName }}",
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
                defaultValue: "Add {{ count }} tracks to {{ playlistName }}",
                count: selectedTracks.length,
                playlistName: recentPlaylist.name,
              }),
            });
          },
        });
      }

      return [
        ...playlistActions,
        {
          type: "divider" as const,
          key: "destructive",
        },
        {
          type: "item",
          key: "remove",
          danger: true,
          label: i18next.t("contextMenu.removeTracks", {
            defaultValue: "Remove {{ count }} tracks",
            count: selectedTracks.length,
          }),
          onClick() {
            handleDelete(selectedIds);
          },
        },
      ];
    },
    [
      listItems,
      handleDelete,
      showToast,
      showPlaylistPicker,
      getMostRecentPlaylist,
    ],
  );

  const handleSubmit = useCallback(
    (itemIds: Set<string>) => {
      const lastItemId = [...itemIds].pop();
      if (!lastItemId) return;
      const [_trackId, trackIndex] = lastItemId.split("/");
      skipToTrackIndex(parseInt(trackIndex, 10));
      setSelectedTrackIds(new Set([]));
    },
    [skipToTrackIndex],
  );

  const handleDrop = useCallback(
    (itemIds: Set<string>, insertAtIndex: number, sourceListId: string) => {
      if (sourceListId === "upNext") {
        const currentIndexes: number[] = Array.from(itemIds).map((itemId) =>
          parseInt(itemId.split("/")[1], 10),
        );

        rearrangeQueue(
          new Set(currentIndexes),
          currentTrackIndex + 1 + insertAtIndex,
        );
      } else if (sourceListId === "playlist") {
        queryPlaylistItemsByIds(Array.from(itemIds))
          .then((items) =>
            items.map((item) => ({
              track: item.track as Track,
              meta: {
                playlistItemId: item.id,
              },
            })),
          )
          .then((newTracks) => {
            addQueueAtIndex(newTracks, currentTrackIndex + 1 + insertAtIndex);
          });
      } else {
        queryTracksByIds(Array.from(itemIds))
          .then((tracks) => tracks.map(trackToQueueItem))
          .then((queueItems) => {
            // The visible Up Next is not the full queue so the indexes
            // don't match, luckily we can fix that problem using the
            // currentTrackIndex + 1 and voila.
            addQueueAtIndex(queueItems, currentTrackIndex + 1 + insertAtIndex);
          });
      }
    },
    [addQueueAtIndex, currentTrackIndex, rearrangeQueue],
  );

  const handleDoubleClick = useCallback(
    (item: ListItem) => {
      skipToTrackIndex(item.position);
      setSelectedTrackIds(new Set([]));
    },
    [skipToTrackIndex],
  );

  const renderItem = useCallback(
    (item: ListItem, state: ListItemState) => (
      <div
        className={classNames([
          "flex px-2 py-1 justify-between gap-4 text-sm",
          state.isDragging && "opacity-50",
          !state.isSelected && "text-white w-full",
          state.isSelected &&
            "text-white bg-white/30 [.selectable-list:focus_&]:bg-white/30",
          state.isSelected && "rounded-t-md rounded-b-md",
          state.isSelected &&
            "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
          state.isSelected &&
            "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
        ])}
      >
        <div className="w-full text-left">
          <div className="line-clamp-1">{item.track.name}</div>
          <span
            className={classNames([
              "line-clamp-1",
              state.isSelected ? "text-white" : "text-white/50",
            ])}
          >
            {item.track.artistName}
          </span>
        </div>
        <div className="tabular-nums">
          {formatDuration(item.track.duration)}
        </div>
      </div>
    ),
    [],
  );

  return (
    <div
      ref={containerRef}
      className={classNames([
        "w-full overflow-y-hidden flex-shrink-1",
        "will-change-[height]",
      ])}
      style={{
        transition: "height 400ms cubic-bezier(0.4, 0, 0.2, 1)",
        height: isVisible ? `${height}px` : "0px",
      }}
    >
      <div className="flex h-full flex-col overflow-y-hidden">
        <div
          role="none"
          className={classNames([
            "block h-full text-center py-8 text-sm text-white/50",
            listItems.length !== 0 && "hidden",
          ])}
          onDragOver={handleDragOver}
          onDrop={handleDropEmpty}
        >
          <Trans i18nKey="upNext.emptyView">No upcoming tracks.</Trans>
        </div>

        <div
          className={classNames([
            "block w-full flex justify-between gap-2 text-left my-2 px-2 flex-shrink-0",
            listItems.length === 0 && "hidden",
          ])}
        >
          <strong className="font-semibold text-md text-white">
            <Trans i18nKey="upNext.title">Up Next</Trans>
          </strong>
          <button
            type="button"
            className="text-sm text-white/50"
            onClick={() => clearNextTracks()}
          >
            <Trans i18nKey="button.clearUpNext">Clear</Trans>
          </button>
        </div>

        <div className="min-h-0 w-full text-left">
          <SelectableList<ListItem>
            id="upNext"
            multiple
            allowDrag
            allowDropFrom={allowDropFrom}
            dropTargetClass="bg-white/80"
            paddingBottom={20}
            items={listItems}
            selectedIds={selectedTrackIds}
            onChange={handleChange}
            onDelete={handleDelete}
            onDrop={handleDrop}
            onSubmit={handleSubmit}
            onContextMenu={handleContextMenu}
            onDoubleClick={handleDoubleClick}
            renderItem={renderItem}
          />
        </div>
      </div>
    </div>
  );
}
