import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import { useAlbum } from "../library";
import { classNames } from "../utils/classNames";
import { AlbumArtwork } from "./AlbumArtwork";
import { BlurredArtwork } from "./BlurredArtwork";
import { NextIcon } from "./icons/NextIcon";
import { PauseIcon } from "./icons/PauseIcon";
import { PlayIcon } from "./icons/PlayIcon";
import { PrevIcon } from "./icons/PrevIcon";
import { UpNextIcon } from "./icons/UpNextIcon";
import { Marquee } from "./Marquee";
import { Scrubber } from "./Scrubber";
import { UpNext } from "./UpNext";

export function MiniPlayer({
  isUpNextOpen,
  onToggleUpNext,
}: {
  isUpNextOpen: boolean;
  onToggleUpNext: () => void;
}) {
  const { t } = useTranslation();
  const { isPlaying, setIsPlaying, scrubTo, addTimeObserver } =
    useAudioManager();
  const { currentTrack, hasNextTrack, hasPrevTrack, prevTrack, nextTrack } =
    useQueue();
  const { data: album } = useAlbum(currentTrack?.albumId);
  const currentTime = useRef<number>(0);

  useEffect(() => {
    const unsubscribe = addTimeObserver(({ currentTime: newCurrentTime }) => {
      currentTime.current = newCurrentTime;
    });

    return unsubscribe;
  }, [addTimeObserver]);

  const artistAlbum = [currentTrack?.artist?.name, album?.name]
    .filter((name) => !!name)
    .join(" - ");

  return (
    <div
      className={classNames([
        "relative min-h-0 flex flex-col overflow-hidden rounded-xl p-3 text-white shadow-lg select-none",
        "transition-[flex-grow] duration-300 ease-out",
        isUpNextOpen ? "grow" : "grow-0",
      ])}
    >
      <BlurredArtwork />

      <div className="relative flex gap-3 items-center">
        <AlbumArtwork
          album={album}
          size="thumbnail"
          className="size-10 flex-shrink-0 rounded-md bg-linear-to-tl from-mist-600 to-mist-700"
        />

        <div className="flex-1 min-w-0 text-left">
          <Marquee
            className="text-sm font-medium"
            text={
              currentTrack?.name ||
              t("player.noTrack.trackName", { defaultValue: "No Track" })
            }
          />
          <div className="text-xs text-white/60">
            <Marquee
              text={
                artistAlbum ||
                t("player.noTrack.artistName", { defaultValue: "No Artist" })
              }
            />
          </div>
        </div>
      </div>

      <div className="relative mt-3">
        <Scrubber />
      </div>

      <div className="relative mt-1 flex justify-between items-center">
        <button
          type="button"
          onClick={onToggleUpNext}
          className={classNames([
            "grid place-items-center size-8 rounded-full cursor-pointer hover:bg-white/10",
            isUpNextOpen ? "text-white" : "text-white/60",
          ])}
        >
          <UpNextIcon
            className="size-4"
            title={t("button.showUpNext", { defaultValue: "Up Next" })}
          />
        </button>

        <div className="flex items-center gap-1">
          <button
            type="button"
            className="grid place-items-center size-8 rounded-full hover:bg-white/10 cursor-pointer"
            onClick={() => {
              if (hasPrevTrack && currentTime.current <= 2) prevTrack();
              else scrubTo(0, true);
            }}
          >
            <PrevIcon
              className="size-4"
              title={t("button.previousTrack", {
                defaultValue: "Previous Track",
              })}
            />
          </button>
          <button
            type="button"
            className="grid place-items-center size-9 rounded-full hover:bg-white/10 cursor-pointer"
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
                className="size-6"
                title={t("button.pauseCurrentTrack", {
                  defaultValue: "Pause Current Track",
                })}
              />
            ) : (
              <PlayIcon
                className="size-6"
                title={t("button.playCurrentTrack", {
                  defaultValue: "Play Current Track",
                })}
              />
            )}
          </button>
          <button
            type="button"
            disabled={!hasNextTrack}
            className="grid place-items-center size-8 rounded-full hover:bg-white/10 disabled:opacity-20 cursor-pointer"
            onClick={() => nextTrack()}
          >
            <NextIcon
              className="size-4"
              title={t("button.nextTrack", { defaultValue: "Next Track" })}
            />
          </button>
        </div>

        <span className="size-8" />
      </div>

      <div
        inert={!isUpNextOpen}
        className="relative h-0 grow flex flex-col -mx-2 overflow-hidden [mask-image:linear-gradient(to_bottom,black_calc(100%-1.5rem),transparent)]"
      >
        <div className="flex-shrink-0 px-2 pt-2 pb-1">
          <div className="h-px bg-white/15" />
        </div>
        <UpNext isVisible={true} animateHeight={false} />
      </div>
    </div>
  );
}
