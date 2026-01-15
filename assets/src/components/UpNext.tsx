import type { PropsWithChildren } from "react";
import { useQueue } from "../hooks/useQueue";
import type { Track } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";

export function UpNext({
  isVisible,
}: PropsWithChildren<{
  isVisible: boolean;
}>) {
  const { queue, currentTrackIndex, skipToTrackIndex, clearNextTracks } =
    useQueue();

  return (
    <div
      className={classNames([
        "w-full grid overflow-hidden flex-shrink-1",
        "transition-[grid-template-rows] duration-600 ease-in-out",
        (!isVisible && "grid-rows-[0fr]") || "grid-rows-[1fr]",
      ])}
    >
      <div className="h-full overflow-hidden">
        <div className="block w-full flex justify-between gap-2 text-left my-2">
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
          {queue
            .map((track, trackIndex): [number, Track] => [trackIndex, track])
            .filter(([trackIndex]) => trackIndex > currentTrackIndex)
            .map(([trackIndex, track]) => {
              return (
                <button
                  key={`track-${trackIndex}`}
                  type="button"
                  className="appearance-none flex w-full justify-between gap-4 text-sm text-accent-600"
                  onDoubleClick={() => {
                    skipToTrackIndex(trackIndex);
                  }}
                >
                  <div className="w-full text-left">
                    <div>{track.name}</div>
                    <span className="text-accent-400">{track.artist.name}</span>
                  </div>
                  <div>{formatDuration(track.duration)}</div>
                </button>
              );
            })}
        </div>
      </div>
    </div>
  );
}

/*
<div className={classNames([
          "w-full grid overflow-hidden flex-shrink-1",
          "transition-[grid-template-rows] duration-600 ease-in-out",
          !isQueueOpen && "grid-rows-[0fr]" || "grid-rows-[1fr]",
        ])}>
          <div className="h-full overflow-hidden">

          </div>
        </div>
      </div>*/
