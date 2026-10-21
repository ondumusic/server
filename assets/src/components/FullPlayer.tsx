import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import { useQueue } from "../hooks/useQueue";
import { useAlbum } from "../library";
import { AlbumArtwork } from "./AlbumArtwork";
import { BlurredArtwork } from "./BlurredArtwork";
import { ChevronDownIcon } from "./icons/ChevronDownIcon";
import { Marquee } from "./Marquee";
import { PlayerControls } from "./PlayerControls";
import { Scrubber } from "./Scrubber";

export function FullPlayer({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const { currentTrack } = useQueue();
  const { data: album } = useAlbum(currentTrack?.albumId);
  const playerRef = useRef<HTMLDivElement>(null);

  // Ensure the full screen player has focus when open, and try to restore
  // it to the previous focus on close.
  useEffect(() => {
    const previousFocus = document.activeElement;
    playerRef.current?.focus();

    return () => {
      if (previousFocus instanceof HTMLElement) previousFocus.focus();
    };
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  const artistAlbum = [currentTrack?.artist?.name, album?.name]
    .filter((name) => !!name)
    .join(" - ");

  return (
    <div
      ref={playerRef}
      tabIndex={-1}
      className="fixed inset-0 z-40 text-white select-none outline-none"
    >
      <BlurredArtwork />

      <button
        type="button"
        onClick={onClose}
        className="absolute z-10 top-4 left-4 grid place-items-center size-10 rounded-full cursor-pointer text-white/70 hover:text-white hover:bg-white/10"
      >
        <ChevronDownIcon
          className="size-6"
          title={t("button.closeNowPlaying", { defaultValue: "Close" })}
        />
      </button>

      <div className="relative h-full flex items-center justify-center px-8 py-16">
        <div className="w-full max-w-[min(26rem,48vh)]">
          <AlbumArtwork
            album={album}
            size="large"
            className="w-full aspect-square rounded-xl shadow-2xl shadow-black/40 bg-linear-to-tl from-stone-600 to-stone-700"
            style={{ viewTransitionName: "now-playing-artwork" }}
          />

          <div className="px-4">
            <div className="mt-6 text-center">
              <Marquee
                className="text-xl font-semibold"
                text={
                  currentTrack?.name ||
                  t("player.noTrack.trackName", { defaultValue: "No Track" })
                }
              />
              <div className="mt-1 text-white/60">
                <Marquee
                  text={
                    artistAlbum ||
                    t("player.noTrack.artistName", {
                      defaultValue: "No Artist",
                    })
                  }
                />
              </div>
            </div>

            <div className="mt-6">
              <Scrubber disabled={!currentTrack} />
            </div>

            <div className="mt-2 flex justify-center">
              <PlayerControls size="large" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
