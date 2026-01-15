import { useState } from "react";
import { useTranslation } from "react-i18next";
import { NextIcon } from "../components/icons/NextIcon";
import { PauseIcon } from "../components/icons/PauseIcon";
import { PlayIcon } from "../components/icons/PlayIcon";
import { PrevIcon } from "../components/icons/PrevIcon";
import { NowPlaying } from "../components/NowPlaying";
import { UpNext } from "../components/UpNext";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";

export function Player() {
  const { t } = useTranslation();
  const { isPlaying, setIsPlaying, currentTime, scrubAndPlay } =
    useAudioManager();
  const { hasNextTrack, hasPrevTrack, prevTrack, nextTrack } = useQueue();

  const [showUpNext, setShowUpNext] = useState(false);

  return (
    <div className="flex flex-col h-full w-full justify-center text-center select-none">
      <NowPlaying />

      <div className="flex justify-center items-center w-full pt-2 flex-shrink-0">
        <div className="flex flex-shrink-0 text-accent-500">
          <button
            type="button"
            className="hidden lg:block disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
            onClick={() => {
              if (hasPrevTrack && currentTime <= 2) prevTrack();
              else scrubAndPlay(0);
            }}
          >
            <PrevIcon
              className="size-6"
              title={t("button.previousTrack", {
                defaultValue: "Previous Track",
              })}
            />
          </button>
          <button
            type="button"
            className="absolute lg:static right-0 top-3 z-[200] disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
            onClick={() => setIsPlaying(!isPlaying)}
          >
            {isPlaying ? (
              <PauseIcon
                className="size-8"
                title={t("button.pauseCurrentTrack", {
                  defaultValue: "Pause Current Track",
                })}
              />
            ) : (
              <PlayIcon
                className="size-8"
                title={t("button.playCurrentTrack", {
                  defaultValue: "Play Current Track",
                })}
              />
            )}
          </button>
          <button
            type="button"
            disabled={!hasNextTrack}
            className="hidden lg:block disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
            onClick={() => nextTrack()}
          >
            <NextIcon
              className="size-6"
              title={t("button.nextTrack", { defaultValue: "Next Track" })}
            />
          </button>
        </div>

        <button
          type="button"
          className="absolute right-8 font-bold text-xl"
          onClick={() => setShowUpNext(!showUpNext)}
        >
          Q
        </button>
      </div>

      <UpNext isVisible={showUpNext} />
    </div>
  );
}
