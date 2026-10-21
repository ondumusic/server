import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import { classNames } from "../utils/classNames";
import { NextIcon } from "./icons/NextIcon";
import { PauseIcon } from "./icons/PauseIcon";
import { PlayIcon } from "./icons/PlayIcon";
import { PrevIcon } from "./icons/PrevIcon";

export function PlayerControls({
  size = "small",
}: {
  size?: "small" | "large";
}) {
  const { t } = useTranslation();
  const currentTime = useRef<number>(0);
  const { isPlaying, setIsPlaying, scrubTo, addTimeObserver } =
    useAudioManager();
  const { currentTrack, hasNextTrack, hasPrevTrack, prevTrack, nextTrack } =
    useQueue();

  useEffect(() => {
    const unsubscribe = addTimeObserver(({ currentTime: newCurrentTime }) => {
      currentTime.current = newCurrentTime;
    });

    return unsubscribe;
  }, [addTimeObserver]);

  const canPlay = !!currentTrack || hasNextTrack;

  const isLarge = size === "large";
  const iconClassName = isLarge ? "size-6" : "size-4";
  const buttonClassName = classNames([
    "grid place-items-center rounded-full hover:bg-white/10",
    "disabled:opacity-20 disabled:hover:bg-transparent cursor-pointer disabled:cursor-default",
    isLarge ? "size-11" : "size-8",
  ]);

  return (
    <div
      className={classNames(["flex items-center", isLarge ? "gap-4" : "gap-1"])}
    >
      <button
        type="button"
        disabled={!currentTrack}
        className={buttonClassName}
        onClick={() => {
          if (hasPrevTrack && currentTime.current <= 2) prevTrack();
          else scrubTo(0, true);
        }}
      >
        <PrevIcon
          className={iconClassName}
          title={t("button.previousTrack", {
            defaultValue: "Previous Track",
          })}
        />
      </button>
      <button
        type="button"
        disabled={!canPlay}
        className={classNames([
          "grid place-items-center rounded-full hover:bg-white/10",
          "disabled:opacity-20 disabled:hover:bg-transparent cursor-pointer disabled:cursor-default",
          isLarge ? "size-14" : "size-9",
        ])}
        onClick={() => {
          if (currentTrack) {
            setIsPlaying(!isPlaying);
          } else {
            nextTrack();
          }
        }}
      >
        {isPlaying ? (
          <PauseIcon
            className={isLarge ? "size-9" : "size-6"}
            title={t("button.pauseCurrentTrack", {
              defaultValue: "Pause Current Track",
            })}
          />
        ) : (
          <PlayIcon
            className={isLarge ? "size-9" : "size-6"}
            title={t("button.playCurrentTrack", {
              defaultValue: "Play Current Track",
            })}
          />
        )}
      </button>
      <button
        type="button"
        disabled={!hasNextTrack}
        className={buttonClassName}
        onClick={() => nextTrack()}
      >
        <NextIcon
          className={iconClassName}
          title={t("button.nextTrack", { defaultValue: "Next Track" })}
        />
      </button>
    </div>
  );
}
