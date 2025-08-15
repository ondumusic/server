import { type ChangeEvent, useMemo, useRef } from "react";
import { Marquee } from "../components/Marquee";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import type { Album } from "../types";
import { findCachedItem } from "../utils/findCachedItem";
import { formatDuration } from "../utils/formatDuration";

export function NowPlaying() {
  const {
    setIsPlaying,
    currentTime,
    duration,
    progressPercentage,
    scrubTo,
    scrubAndPlay,
  } = useAudioManager();
  const { currentTrack } = useQueue();
  const scrubTime = useRef<number>(0);
  const isScrubbing = useRef<boolean>(false);

  const currentAlbum = useMemo(() => {
    if (!currentTrack) return;
    return findCachedItem<Album>(
      ["albumList", currentTrack.albumArtistId],
      currentTrack.albumId,
    );
  }, [currentTrack]);

  const onScrubStart = () => {
    isScrubbing.current = true;
    setIsPlaying(false);
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
    <div className="flex-shrink-0 relative w-1/2 max-w-xl select-none group/player">
      <div className="relative bg-emerald-700/60 p-2 rounded-lg overflow-hidden cursor-default">
        <div className="flex justify-between items-end tabular-nums text-white/70 pb-1">
          <div className="overflow-hidden mx-12 order-2">
            <Marquee
              className="text-white/90 font-semibold"
              text={`${currentTrack?.name}`}
            />
            <div className="mx-8">
              <Marquee
                text={`${currentTrack?.artist?.name} - ${currentAlbum?.name}`}
              />
            </div>
          </div>

          <span className="flex-shrink-0 text-xs order-1">
            {formatDuration(currentTime)}
          </span>
          <span className="flex-shrink-0 text-xs order-3">
            {formatDuration(duration)}
          </span>
        </div>

        <div className="absolute z-[10] bottom-0 left-0 right-0 bg-emerald-300/40 h-1">
          <div
            className="h-1 rounded-tr-lg rounded-br-lg bg-emerald-200"
            style={{ width: `${progressPercentage}%` }}
          ></div>
        </div>
      </div>
      <input
        type="range"
        className="
            appearance-none bg-transparent z-[20]
            absolute left-0 right-0 bottom-0
            [&::-webkit-slider-runnable-track]:bg-transparent
            [&::-webkit-slider-thumb]:appearance-none
            [&::-webkit-slider-thumb]:h-3
            [&::-webkit-slider-thumb]:w-3
            [&::-webkit-slider-thumb]:rounded-md
            [&::-webkit-slider-thumb]:transition-all
            [&::-webkit-slider-thumb]:translate-y-[4px]
            [&::-webkit-slider-thumb]:translate-x-[-1px]
            [&::-webkit-slider-thumb]:bg-transparent
            group-hover/player:[&::-webkit-slider-thumb]:bg-white
            group-hover/player:[&::-webkit-slider-thumb]:shadow-xl
          "
        value={currentTime}
        min={0}
        max={duration}
        onChange={onScrub}
        onMouseDown={onScrubStart}
        onMouseUp={onScrubEnd}
      />
    </div>
  );
}
