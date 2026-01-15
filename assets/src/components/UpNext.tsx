import { type PropsWithChildren, useMemo, useState } from "react";
import { type ListItem, SelectableList } from "../components/SelectableList";
import { useQueue } from "../hooks/useQueue";
import type { Track } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";

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
  const { queue, currentTrackIndex, skipToTrackIndex, clearNextTracks } =
    useQueue();

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

  return (
    <div
      className={classNames([
        "w-full grid overflow-y-hidden flex-shrink-1",
        "transition-[grid-template-rows] duration-400 ease-in-out",
        (!isVisible && "grid-rows-[0fr]") || "grid-rows-[1fr]",
      ])}
    >
      <div className="flex flex-col h-full overflow-y-hidden">
        <div className="block w-full flex justify-between gap-2 text-left my-2 px-2 flex-shrink-0">
          <strong className="font-semibold text-md">Up Next</strong>
          <button
            type="button"
            className="text-sm text-accent-400"
            onClick={() => clearNextTracks()}
          >
            Clear
          </button>
        </div>
        <div className="h-full w-full space-y-2 text-left overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <SelectableList<QueueItem>
            multiple
            items={listItems}
            selectedIds={new Set<string>(selectedTrackIds)}
            onChange={(itemIds) => setSelectedTrackIds(Array.from(itemIds))}
            onSubmit={(itemIds) => {
              const lastItemId = [...itemIds].pop();
              if (!lastItemId) return;
              const [_trackId, trackIndex] = lastItemId.split("/");
              skipToTrackIndex(parseInt(trackIndex, 10));
              setSelectedTrackIds([]);
            }}
            onDoubleClick={(item) => {
              skipToTrackIndex(item.trackIndex);
              setSelectedTrackIds([]);
            }}
            renderItem={(item, state) => (
              <div
                className={classNames([
                  "flex px-2 py-1 justify-between gap-4 text-sm",
                  !state.isSelected && "text-accent-600 w-full",
                  state.isSelected && "text-white bg-accent-500",
                  state.isSelected && "rounded-t-md rounded-b-md",
                  state.isSelected &&
                    "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
                  state.isSelected &&
                    "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
                ])}
              >
                <div className="w-full text-left">
                  <div>{item.track.name}</div>
                  <span
                    className={
                      state.isSelected ? "text-white" : "text-accent-400"
                    }
                  >
                    {item.track.artist.name}
                  </span>
                </div>
                <div>{formatDuration(item.track.duration)}</div>
              </div>
            )}
          />
        </div>
      </div>
    </div>
  );
}
