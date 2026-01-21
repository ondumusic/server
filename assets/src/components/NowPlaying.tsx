import {
  type ChangeEvent,
  type PropsWithChildren,
  useEffect,
  useMemo,
  useRef,
} from "react";
import { Marquee } from "../components/Marquee";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import i18next from "../i18next";
import type { Album } from "../types";
import { findCachedItem } from "../utils/findCachedItem";
import { formatDuration } from "../utils/formatDuration";
import {
  resetAccentColor,
  updateAccentColor,
} from "../utils/updateAccentColor";

export function NowPlaying({
  currentTime,
  progressPercentage,
}: PropsWithChildren<{
  currentTime: number;
  progressPercentage: number;
}>) {
  const { setIsPlaying, duration, scrubTo, scrubAndPlay } = useAudioManager();
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

  useEffect(() => {
    if (!currentAlbum) return;
    if (!currentAlbum.artworkUrl) {
      resetAccentColor();
    }
  }, [currentAlbum]);

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

  const trackName = currentTrack?.name || "";
  const artistAlbum = [currentTrack?.artist?.name, currentAlbum?.name].filter(
    (name) => !!name,
  );

  return (
    <div className="flex flex-wrap pr-10 lg:pr-0 gap-2 lg:block w-full cursor-default flex-shrink-0 lg:px-2">
      {currentAlbum?.artworkUrl ? (
        <img
          src={currentAlbum?.artworkUrl}
          alt=""
          className="w-20 lg:w-full aspect-square object-cover object-center lg:rounded-md overflow-hidden lg:shadow-md lg:mb-4"
          onLoad={(e) => updateAccentColor(e.target as HTMLImageElement)}
        />
      ) : (
        <div className="w-20 aspect-square bg-gray-100 lg:w-full"></div>
      )}

      <div className="text-left w-[calc(100%-120px)] lg:w-full lg:text-center overflow-hidden mb-4">
        <Marquee
          className="transition-colors duration-400 text-accent-600 text-lg font-medium"
          text={
            trackName ||
            i18next.t("player.noTrack.trackName", {
              defaultValue: "No Track",
            })
          }
        />
        <div className="font-normal text-sm text-accent-400">
          <Marquee text={artistAlbum.join(" - ")} />
        </div>
      </div>

      <div className="absolute bottom-4 left-22 right-2 lg:static group/timeline">
        <div className="flex justify-between items-end tabular-nums transition-colors duration-400 text-accent-400 text-xs mb-0.5 lg:mb-2">
          <span>{formatDuration(currentTime)}</span>
          <span>{formatDuration(duration)}</span>
        </div>

        <div className="relative">
          <div className="absolute z-[10] top-0 lg:top-auto lg:bottom-0 left-0 right-0 bg-accent-300/40 h-1 rounded-lg overflow-hidden">
            <div
              className="h-1 lg:rounded-tr-lg lg:rounded-br-lg bg-accent-400"
              style={{ width: `${progressPercentage}%` }}
            ></div>
          </div>
          <input
            type="range"
            className="
                appearance-none bg-transparent z-[20] transition-colors duration-400
                absolute left-0 right-0 top-0 lg:top-auto lg:bottom-0
                [&::-webkit-slider-runnable-track]:bg-transparent
                [&::-webkit-slider-thumb]:appearance-none
                [&::-webkit-slider-thumb]:h-3
                [&::-webkit-slider-thumb]:w-3
                [&::-webkit-slider-thumb]:rounded-md
                [&::-webkit-slider-thumb]:transition-all
                [&::-webkit-slider-thumb]:translate-y-[-4px]
                [&::-webkit-slider-thumb]:shadow-none
                lg:[&::-webkit-slider-thumb]:translate-y-[4px]
                [&::-webkit-slider-thumb]:translate-x-[-1px]
                [&::-webkit-slider-thumb]:bg-transparent
                group-hover/timeline:[&::-webkit-slider-thumb]:bg-accent-600
                group-hover/timeline:[&::-webkit-slider-thumb]:shadow-xl
              "
            value={currentTime}
            min={0}
            max={duration}
            onChange={onScrub}
            onMouseDown={onScrubStart}
            onMouseUp={onScrubEnd}
          />
        </div>
      </div>
    </div>
  );
}
