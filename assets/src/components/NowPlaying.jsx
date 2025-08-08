import { usePlayer } from "../hooks/usePlayer";
import { formatDuration } from "../utils/formatDuration";

export function NowPlaying() {
  const { currentSong, duration, currentTime, percentage } = usePlayer();

  return (
    <div className="bg-emerald-700/60 p-2 rounded-lg max-w-xl mx-auto relative overflow-hidden">
      <div className="flex justify-between items-end tabular-nums text-white/70 pb-1">
        <div class="order-2">
          <h4 className="whitespace-nowrap text-ellipsis overflow-hidden text-white/90 font-semibold">
            {currentSong.name}
          </h4>
          <h5 className="whitespace-nowrap text-ellipsis overflow-hidden">
            The Artist - The Album
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
          style={{ width: `${percentage}%` }}
        ></div>
      </div>
    </div>
  );
}
