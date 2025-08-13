import { useTranslation } from "react-i18next";
import { NextIcon } from "../components/icons/NextIcon";
import { PauseIcon } from "../components/icons/PauseIcon";
import { PlayIcon } from "../components/icons/PlayIcon";
import { PrevIcon } from "../components/icons/PrevIcon";
import { NowPlaying } from "../components/NowPlaying";
import { useAudioManager } from "../hooks/useAudioManager";
import { usePlayer } from "../hooks/usePlayer";

export function Player() {
  const { t } = useTranslation();
  const { scrubAndPlay } = useAudioManager();
  const {
    isPlaying,
    setIsPlaying,
    currentTime,
    hasNextTrack,
    hasPrevTrack,
    prevTrack,
    nextTrack,
  } = usePlayer();

  return (
    <div className="flex-shrink-0 bg-emerald-600 text-white p-3 text-sm text-center select-none">
      <div className="flex justify-center items-center w-full">
        <button
          type="button"
          className="disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
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
          className="disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
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
          className="disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
          onClick={() => nextTrack()}
        >
          <NextIcon
            className="size-6"
            title={t("button.nextTrack", { defaultValue: "Next Track" })}
          />
        </button>

        <div className="w-8"></div>
        <NowPlaying />
      </div>
    </div>
  );
}
