import { type ChangeEvent, useEffect, useRef, useState } from "react";
import { AlbumArtwork } from "../components/AlbumArtwork";
import { Marquee } from "../components/Marquee";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import i18next from "../i18next";
import { useAlbum } from "../library";
import { artworkUrl } from "../utils/artwork";
import { formatDuration } from "../utils/formatDuration";
import {
  resetBackgroundColor,
  updateBackgroundColor,
} from "../utils/updateBackgroundColor";

export function NowPlaying() {
  const { setIsPlaying, duration, scrubTo, addTimeObserver } =
    useAudioManager();
  const { currentTrack } = useQueue();
  const scrubTime = useRef<number>(0);
  const isScrubbing = useRef<boolean>(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [progressPercentage, setProgressPercentage] = useState(0);

  useEffect(() => {
    const unsubscribe = addTimeObserver(
      ({ currentTime, progressPercentage }) => {
        setCurrentTime(currentTime);
        setProgressPercentage(progressPercentage);
      },
    );

    return unsubscribe;
  }, [addTimeObserver]);

  const { data: currentAlbum } = useAlbum(currentTrack?.albumId);

  useEffect(() => {
    if (!currentAlbum) return;
    if (!artworkUrl(currentAlbum)) {
      resetBackgroundColor();
    }
  }, [currentAlbum]);

  const handleScrubStart = () => {
    isScrubbing.current = true;
    setIsPlaying(false);
  };

  const handleScrub = (event: ChangeEvent<HTMLInputElement>) => {
    if (!isScrubbing.current) return;
    const newCurrentTime = parseFloat(event.target.value);
    scrubTime.current = newCurrentTime;
    scrubTo(newCurrentTime);
  };

  const handleScrubEnd = () => {
    isScrubbing.current = false;
    if (!scrubTime.current) return;
    scrubTo(scrubTime.current, true);
  };

  const trackName = currentTrack?.name || "";
  const artistAlbum = [currentTrack?.artist?.name, currentAlbum?.name].filter(
    (name) => !!name,
  );

  return (
    <div className="flex flex-wrap pr-10 lg:pr-0 gap-2 lg:block w-full cursor-default flex-shrink-0 lg:px-2">
      <AlbumArtwork
        album={currentAlbum}
        size="large"
        className="w-20 lg:w-full flex-shrink-0 aspect-square bg-linear-to-tl from-mist-600 to-mist-700 lg:rounded-md lg:shadow-md lg:mb-4"
        onLoad={updateBackgroundColor}
      />

      <div className="text-left w-[calc(100%-120px)] lg:w-full lg:text-center overflow-hidden pt-2 lg:pt-0 mb-4">
        <Marquee
          className="transition-colors duration-400 text-white text-sm lg:text-lg font-medium"
          text={
            trackName ||
            i18next.t("player.noTrack.trackName", {
              defaultValue: "No Track",
            })
          }
        />
        <div className="font-normal text-xs lg:text-sm text-white/50">
          <Marquee
            text={
              artistAlbum.join(" - ") ||
              i18next.t("player.noTrack.artistName", {
                defaultValue: "No Artist",
              })
            }
          />
        </div>
      </div>

      <div className="absolute bottom-4 left-22 right-2 lg:static group/timeline">
        <div className="flex justify-between items-end tabular-nums transition-colors duration-200 text-white/50 group-hover/timeline:text-white text-xs mb-0.5 lg:mb-2">
          <span>{formatDuration(currentTime)}</span>
          <span>{formatDuration(duration)}</span>
        </div>

        <div className="relative">
          <div className="absolute z-[10] top-0 lg:top-auto lg:bottom-0 left-0 right-0 bg-white/30 h-1 rounded-lg overflow-hidden">
            <div
              className="h-1 lg:rounded-tr-lg lg:rounded-br-lg bg-white"
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
                group-hover/timeline:[&::-webkit-slider-thumb]:bg-white
                group-hover/timeline:[&::-webkit-slider-thumb]:shadow-xl
              "
            value={currentTime}
            min={0}
            max={duration}
            onChange={handleScrub}
            onMouseDown={handleScrubStart}
            onMouseUp={handleScrubEnd}
          />
        </div>
      </div>
    </div>
  );
}
