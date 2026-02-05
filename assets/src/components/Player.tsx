import { type PropsWithChildren, useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { NextIcon } from "../components/icons/NextIcon";
import { PanelCloseIcon } from "../components/icons/PanelCloseIcon";
import { PanelOpenIcon } from "../components/icons/PanelOpenIcon";
import { PauseIcon } from "../components/icons/PauseIcon";
import { PlayIcon } from "../components/icons/PlayIcon";
import { PrevIcon } from "../components/icons/PrevIcon";
import { UpNextIcon } from "../components/icons/UpNextIcon";
import { NowPlaying } from "../components/NowPlaying";
import { UpNext } from "../components/UpNext";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import { classNames } from "../utils/classNames";

const PlaybackControls = ({
  isPanelOpen,
  setIsPanelOpen,
  showUpNext,
  setShowUpNext,
}: PropsWithChildren<{
  isPanelOpen: boolean;
  setIsPanelOpen: (_isPanelOpen: boolean) => void;
  showUpNext: boolean;
  setShowUpNext: (_isPanelOpen: boolean) => void;
}>) => {
  const { t } = useTranslation();
  const { isPlaying, setIsPlaying, scrubTo, addTimeObserver } =
    useAudioManager();
  const { currentTrack, hasNextTrack, hasPrevTrack, prevTrack, nextTrack } =
    useQueue();
  const [currentTime, setCurrentTime] = useState(0);

  useEffect(() => {
    const unsubscribe = addTimeObserver(({ currentTime }) => {
      setCurrentTime(currentTime);
    });

    return unsubscribe;
  }, [addTimeObserver]);

  return (
    <div className="flex justify-center items-center lg:w-full lg:pt-2 lg:px-2 flex-shrink-0">
      <div className="flex flex-shrink-0 text-accent-500">
        <button
          type="button"
          className="hidden lg:block disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
          onClick={() => {
            if (hasPrevTrack && currentTime <= 2) prevTrack();
            else scrubTo(0, true);
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
          className="absolute lg:static right-0 top-0 lg:top-3 z-[200] disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md cursor-pointer"
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
        className="hidden lg:block absolute cursor-pointer left-6 text-accent-500"
        onClick={() => setShowUpNext(!showUpNext)}
      >
        <UpNextIcon
          className="size-6"
          title={t("button.showUpNext", { defaultValue: "Up Next" })}
        />
      </button>

      <button
        type="button"
        className="hidden lg:block absolute cursor-pointer right-6 text-accent-500"
        onClick={() => setIsPanelOpen(!isPanelOpen)}
      >
        <PanelCloseIcon
          className={classNames(["size-6", !isPanelOpen && "hidden"])}
          title={t("button.closePanel", {
            defaultValue: "Close Music Browser",
          })}
        />

        <PanelOpenIcon
          className={classNames(["size-6", isPanelOpen && "hidden"])}
          title={t("button.openPanel", {
            defaultValue: "Open Music Browser",
          })}
        />
      </button>
    </div>
  );
};

export function Player({
  isPanelOpen,
  setIsPanelOpen,
}: PropsWithChildren<{
  isPanelOpen: boolean;
  setIsPanelOpen: (_isPanelOpen: boolean) => void;
}>) {
  const [showUpNext, setShowUpNext] = useState<boolean>(false);

  return (
    <div className="flex flex-row lg:flex-col h-full w-full justify-center text-center select-none">
      <NowPlaying />

      <PlaybackControls
        isPanelOpen={isPanelOpen}
        setIsPanelOpen={setIsPanelOpen}
        showUpNext={showUpNext}
        setShowUpNext={setShowUpNext}
      />

      <UpNext isVisible={showUpNext} />
    </div>
  );
}
