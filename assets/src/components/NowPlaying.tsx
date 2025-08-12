import { type ChangeEvent, useMemo, useRef } from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { usePlayer } from "../hooks/usePlayer";
import type { Album } from "../types";
import { findCachedItem } from "../utils/findCachedItem";
import { formatDuration } from "../utils/formatDuration";

export function NowPlaying() {
  const { currentTrack, duration, currentTime, progressPercentage } =
    usePlayer();
  const { scrubTo, scrubAndPlay } = useAudioManager();
  const scrubTime = useRef<number>(0);
  const isScrubbing = useRef<boolean>(false);

  const album = useMemo(() => {
    if (!currentTrack) return;
    return findCachedItem<Album>(
      ["albumList", currentTrack.artistId],
      currentTrack.albumId,
    );
  }, [currentTrack]);

  const onScrubStart = () => {
    isScrubbing.current = true;
  };

  const onScrub = (event: ChangeEvent<HTMLInputElement>) => {
    if (!isScrubbing.current) return;
    const newCurrentTime = parseFloat(event.target.value);
    scrubTime.current = newCurrentTime;
    scrubTo(newCurrentTime);
  };

  const onScrubEnd = () => {
    isScrubbing.current = false;
    if (!scrubTime.current) return;
    scrubAndPlay(scrubTime.current);
  };

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
        <input
          type="range"
          className="
            appearance-none bg-transparent
            absolute left-0 right-0 bottom-0
            [&::-webkit-slider-runnable-track]:bg-transparent
            [&::-webkit-slider-thumb]:appearance-none
            [&::-webkit-slider-thumb]:h-1
            [&::-webkit-slider-thumb]:w-2
            [&::-webkit-slider-thumb]:bg-transparent
          "
          value={currentTime}
          min={0}
          max={duration}
          onChange={onScrub}
          onMouseDown={onScrubStart}
          onMouseUp={onScrubEnd}
        />
        <div
          className="h-1 bg-emerald-200 rounded-lg"
          style={{ width: `${progressPercentage}%` }}
        ></div>
      </div>
    </div>
  );
}
