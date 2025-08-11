import { useMemo } from "react";
import { usePlayer } from "../hooks/usePlayer";
import type { Album } from "../types";
import { findCachedItem } from "../utils/findCachedItem";
import { formatDuration } from "../utils/formatDuration";

export function NowPlaying() {
  const { currentTrack, duration, currentTime, progressPercentage } =
    usePlayer();

  const album = useMemo(() => {
    if (!currentTrack) return;
    return findCachedItem<Album>(
      ["albumList", currentTrack.artistId],
      currentTrack.albumId,
    );
  }, [currentTrack]);

  return (
    <div className="flex-shrink-0 w-1/2 max-w-xl bg-emerald-700/60 p-2 rounded-lg relative overflow-hidden">
      <div className="flex justify-between items-end tabular-nums text-white/70 pb-1">
        <div className="overflow-hidden mx-12 order-2">
          <h4 className="whitespace-nowrap text-ellipsis overflow-hidden text-white/90 font-semibold">
            {currentTrack?.name}
          </h4>
          <h5 className="whitespace-nowrap text-ellipsis overflow-hidden mx-8">
            {currentTrack?.artist?.name} - {album?.name}
          </h5>
        </div>

        <span className="flex-shrink-0 text-xs order-1">
          {formatDuration(currentTime)}
        </span>
        <span className="flex-shrink-0 text-xs order-3">
          {formatDuration(duration)}
        </span>
      </div>

      <div className="absolute bottom-0 left-0 right-0 bg-emerald-300/40 h-1 overflow-hidden">
        <div
          className="h-1 bg-emerald-200 rounded-lg"
          style={{ width: `${progressPercentage}%` }}
        ></div>
      </div>
    </div>
  );
}
