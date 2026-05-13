import {
  type DragEvent,
  type PropsWithChildren,
  useEffect,
  useState,
} from "react";
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
    <div className="flex justify-center items-center lg:w-full lg:pt-6 lg:px-2 flex-shrink-0">
      <div className="flex flex-shrink-0 text-white gap-2">
        <button
          type="button"
          className="hidden lg:grid place-items-center disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-full w-12 h-12 cursor-pointer"
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
          className="absolute lg:static grid place-items-center right-0 top-0 lg:top-3 z-[200] disabled:opacity-20 active:opacity-80 p-2 rounded-full w-12 h-12 cursor-pointer bg-white text-black"
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
          className="hidden lg:grid place-items-center disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-full w-12 h-12 cursor-pointer"
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
        className="hidden lg:block absolute cursor-pointer left-6 text-white"
        onClick={() => setShowUpNext(!showUpNext)}
      >
        <UpNextIcon
          className="size-6"
          title={t("button.showUpNext", { defaultValue: "Up Next" })}
        />
      </button>

      <button
        type="button"
        className="hidden lg:block absolute cursor-pointer right-4 text-white"
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

  // UpNext contains the actual drop target so if user is dragging over here
  // we should
  const handleDragOver = (e: DragEvent) => {
    const sourceListId = e.dataTransfer.types
      .find((t) => t.startsWith("application/x-list-"))
      ?.replace("application/x-list-", "");
    if (!sourceListId) return;

    setShowUpNext(true);
  };

  return (
    // biome-ignore lint/a11y/noStaticElementInteractions: allow dragging events
    <div
      className="flex flex-row lg:flex-col h-full w-full justify-center text-center select-none"
      onDragOver={handleDragOver}
    >
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
