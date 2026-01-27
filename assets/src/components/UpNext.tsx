import {
  type DragEvent,
  type PropsWithChildren,
  useCallback,
  useMemo,
  useState,
} from "react";
import { Trans } from "react-i18next";
import {
  type ListItem,
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import { useQueue } from "../hooks/useQueue";
import type { Track } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";
import { queryClient } from "../utils/queryClient";

type QueueItem = ListItem & {
  track: Track;
  trackIndex: number;
};

export function UpNext({
  isVisible,
}: PropsWithChildren<{
  isVisible: boolean;
}>) {
  const [selectedTrackIds, setSelectedTrackIds] = useState<string[]>([]);
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

  const listItems: QueueItem[] = useMemo(() => {
    return (
      queue
        .map(
          (track, trackIndex): QueueItem => ({
            // We need unique IDs for SelectableList, however we also support
            // having the same track multiple times. So we include the trackIndex
            // as part of the ID.
            id: [track.id, trackIndex].join("/"),
            trackIndex,
            track,
          }),
        )
        // We only want to display upcoming items from the queue, as the rest
        // is considered "history".
        .filter((item) => item.trackIndex > currentTrackIndex)
    );
  }, [queue, currentTrackIndex]);

  const onDragOver = useCallback((e: DragEvent) => {
    e.stopPropagation();
    e.preventDefault();
  }, []);

  const onDropEmpty = useCallback(
    (e: DragEvent) => {
      e.preventDefault();
      e.stopPropagation();

      try {
        const { itemIds } = JSON.parse(
          e.dataTransfer.getData("application/json"),
        );

        const newTracks: Track[] = Array.from(itemIds).flatMap((itemId) => {
          const track = queryClient.getQueryData<Track>(["track", itemId]);

          if (track) return [track];
          return [];
        });

        addQueueAfter(newTracks);
      } catch (_error) {
        return;
      }
    },
    [addQueueAfter],
  );

  const onChange = useCallback(
    (itemIds: Set<string>) => setSelectedTrackIds(Array.from(itemIds)),
    [],
  );

  const onDelete = useCallback(
    (itemIds: Set<string>) => {
      const selectedItems = listItems.filter((item) => itemIds.has(item.id));
      const trackIndexes = selectedItems.map((item) => item.trackIndex);
      if (trackIndexes.length !== 0) {
        removeFromQueue(trackIndexes);
      }
    },
    [listItems, removeFromQueue],
  );

  const onSubmit = useCallback(
    (itemIds: Set<string>) => {
      const lastItemId = [...itemIds].pop();
      if (!lastItemId) return;
      const [_trackId, trackIndex] = lastItemId.split("/");
      skipToTrackIndex(parseInt(trackIndex, 10));
      setSelectedTrackIds([]);
    },
    [skipToTrackIndex],
  );

  const onContextMenu = useCallback(() => [], []);

  const onDrop = useCallback(
    (itemIds: Set<string>, insertAtIndex: number, sourceListId: string) => {
      if (sourceListId === "upNext") {
        const currentIndexes: number[] = Array.from(itemIds).map((itemId) =>
          parseInt(itemId.split("/")[1], 10),
        );

        rearrangeQueue(
          new Set(currentIndexes),
          currentTrackIndex + 1 + insertAtIndex,
        );
      } else {
        const newTracks: Track[] = Array.from(itemIds).flatMap((itemId) => {
          const track = queryClient.getQueryData<Track>(["track", itemId]);

          if (track) return [track];
          return [];
        });

        // The visible Up Next is not the full queue so the indexes
        // don't match, luckily we can fix that problem using the
        // currentTrackIndex + 1 and voila.
        addQueueAtIndex(newTracks, currentTrackIndex + 1 + insertAtIndex);
      }
    },
    [addQueueAtIndex, currentTrackIndex, rearrangeQueue],
  );

  const onDoubleClick = useCallback(
    (item: QueueItem) => {
      skipToTrackIndex(item.trackIndex);
      setSelectedTrackIds([]);
    },
    [skipToTrackIndex],
  );

  const renderItem = useCallback(
    (item: QueueItem, state: ListItemState) => (
      <div
        className={classNames([
          "flex px-2 py-1 justify-between gap-4 text-sm",
          state.isDragging && "opacity-50",
          !state.isSelected && "text-accent-600 w-full",
          state.isSelected &&
            "text-white bg-accent-400 [.selectable-list:focus_&]:bg-accent-500",
          state.isSelected && "rounded-t-md rounded-b-md",
          state.isSelected &&
            "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
          state.isSelected &&
            "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
        ])}
      >
        <div className="w-full text-left">
          <div>{item.track.name}</div>
          <span className={state.isSelected ? "text-white" : "text-accent-400"}>
            {item.track.artist.name}
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
      className={classNames([
        "w-full grid overflow-y-hidden flex-shrink-1",
        "transition-[grid-template-rows] duration-400 ease-in-out",
        (!isVisible && "grid-rows-[0fr]") || "grid-rows-[1fr]",
      ])}
    >
      <div className="flex flex-col h-full overflow-y-hidden">
        <div
          role="none"
          className={classNames([
            "block text-center py-8 text-sm text-accent-400",
            listItems.length !== 0 && "hidden",
          ])}
          onDragOver={onDragOver}
          onDrop={onDropEmpty}
        >
          <Trans i18nKey="upNext.emptyView">No upcoming tracks.</Trans>
        </div>

        <div
          className={classNames([
            "block w-full flex justify-between gap-2 text-left my-2 px-2 flex-shrink-0",
            listItems.length === 0 && "hidden",
          ])}
        >
          <strong className="font-semibold text-md">
            <Trans i18nKey="upNext.title">Up Next</Trans>
          </strong>
          <button
            type="button"
            className="text-sm text-accent-400"
            onClick={() => clearNextTracks()}
          >
            <Trans i18nKey="button.clearUpNext">Clear</Trans>
          </button>
        </div>
        <div className="h-full w-full text-left">
          <SelectableList<QueueItem>
            id="upNext"
            multiple
            allowDrag
            allowDropFrom={["upNext", "albumTracks"]}
            items={listItems}
            selectedIds={new Set<string>(selectedTrackIds)}
            onChange={onChange}
            onDelete={onDelete}
            onDrop={onDrop}
            onSubmit={onSubmit}
            onContextMenu={onContextMenu}
            onDoubleClick={onDoubleClick}
            renderItem={renderItem}
          />
        </div>
      </div>
    </div>
  );
}
