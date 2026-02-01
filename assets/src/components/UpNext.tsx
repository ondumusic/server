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
  const containerRef = useRef<HTMLDivElement>(null);
  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set([]),
  );
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

  const allowDropFrom = useMemo(() => ["upNext", "albumTracks"], []);

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
    (itemIds: Set<string>) => setSelectedTrackIds(itemIds),
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
      setSelectedTrackIds(new Set([]));
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
      setSelectedTrackIds(new Set([]));
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
          <div className="line-clamp-1">{item.track.name}</div>
          <span
            className={classNames([
              "line-clamp-1",
              state.isSelected ? "text-white" : "text-accent-400",
            ])}
          >
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
            "block h-full text-center py-8 text-sm text-accent-400",
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

        <div className="min-h-0 w-full text-left">
          <SelectableList<QueueItem>
            id="upNext"
            multiple
            allowDrag
            allowDropFrom={allowDropFrom}
            items={listItems}
            selectedIds={selectedTrackIds}
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
