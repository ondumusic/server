import { useTranslation } from "react-i18next";
import { useQueue } from "../hooks/useQueue";
import { useAlbum } from "../library";
import { classNames } from "../utils/classNames";
import { AlbumArtwork } from "./AlbumArtwork";
import { BlurredArtwork } from "./BlurredArtwork";
import { UpNextIcon } from "./icons/UpNextIcon";
import { Marquee } from "./Marquee";
import { PlayerControls } from "./PlayerControls";
import { Scrubber } from "./Scrubber";
import { UpNext } from "./UpNext";

export function MiniPlayer({
  isUpNextOpen,
  onToggleUpNext,
  isNowPlayingOpen,
  onNowPlayingOpen,
}: {
  isUpNextOpen: boolean;
  onToggleUpNext: () => void;
  isNowPlayingOpen: boolean;
  onNowPlayingOpen: () => void;
}) {
  const { t } = useTranslation();
  const { currentTrack } = useQueue();
  const { data: album } = useAlbum(currentTrack?.albumId);

  const artistAlbum = [currentTrack?.artist?.name, album?.name]
    .filter((name) => !!name)
    .join(" - ");

  return (
    <div
      className={classNames([
        "relative min-h-0 flex flex-col overflow-hidden rounded-xl p-3 text-white shadow-lg select-none",
        "dark:shadow-xl dark:shadow-black/50",
        "transition-[flex-grow] duration-300 ease-out",
        isUpNextOpen ? "grow" : "grow-0",
      ])}
    >
      <BlurredArtwork />

      <div className="relative flex gap-3 items-center">
        <button
          type="button"
          disabled={!currentTrack}
          onClick={onNowPlayingOpen}
          className="flex-shrink-0 cursor-pointer disabled:cursor-default"
        >
          <AlbumArtwork
            album={album}
            size="thumbnail"
            className="size-12 rounded-md shadow-md shadow-black/30 bg-linear-to-tl from-stone-600 to-stone-700"
            // Grows into the cover of the full screen player when opened, only
            // one element can have the name at a time.
            style={{
              viewTransitionName: isNowPlayingOpen
                ? undefined
                : "now-playing-artwork",
            }}
          />
        </button>

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
        <Scrubber disabled={!currentTrack} />
      </div>

      <div className="relative mt-1 flex justify-between items-center">
        <button
          type="button"
          onClick={onToggleUpNext}
          className={classNames([
            "grid place-items-center size-8 -ml-2 rounded-full cursor-pointer hover:bg-white/10",
            isUpNextOpen ? "text-white" : "text-white/60",
          ])}
        >
          <UpNextIcon
            className="size-4"
            title={t("button.showUpNext", { defaultValue: "Up Next" })}
          />
        </button>

        <PlayerControls />

        <span className="size-8 -mr-2" />
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
