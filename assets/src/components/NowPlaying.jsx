import { useMemo } from "react";
import { usePlayer } from "../hooks/usePlayer";
import { formatDuration } from "../utils/formatDuration";
import { queryClient } from "../utils/queryClient";

function findCachedItem(queryKey, id) {
  const cache = queryClient.getQueryData(queryKey);
  if (!cache) return;
  const entries = cache.pages.flatMap((page) => page.entries);
  return entries.find((entry) => entry.id === id);
}

export function NowPlaying() {
  const { currentSong, duration, currentTime, progressPercentage } =
    usePlayer();

  const artist = useMemo(() => {
    if (!currentSong) return;
    return findCachedItem(["artistList"], currentSong.artistId);
  }, [currentSong]);

  const album = useMemo(() => {
    if (!currentSong) return;
    return findCachedItem(
      ["albumList", currentSong.artistId],
      currentSong.albumId,
    );
  }, [currentSong]);

  return (
    <div className="flex-shrink-0 w-xl bg-emerald-700/60 p-2 rounded-lg relative overflow-hidden">
      <div className="flex justify-between items-end tabular-nums text-white/70 pb-1">
        <div class="order-2">
          <h4 className="whitespace-nowrap text-ellipsis overflow-hidden text-white/90 font-semibold">
            {currentSong?.name}
          </h4>
          <h5 className="whitespace-nowrap text-ellipsis overflow-hidden">
            {artist?.name} - {album?.name}
          </h5>
        </div>

        <span class="flex-shrink-0 text-xs order-1">
          {formatDuration(currentTime)}
        </span>
        <span class="flex-shrink-0 text-xs order-3">
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
