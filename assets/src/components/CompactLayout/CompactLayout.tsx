import { Outlet, useLocation } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { useQueue } from "../../hooks/useQueue";
import { useAlbum } from "../../library";
import { classNames } from "../../utils/classNames";
import { AlbumArtwork } from "../AlbumArtwork";
import { BlurredArtwork } from "../BlurredArtwork";
import { FullPlayer } from "../FullPlayer";
import { MenuIcon } from "../icons/MenuIcon";
import { UpNextIcon } from "../icons/UpNextIcon";
import { Marquee } from "../Marquee";
import { NoticeBanner } from "../NoticeBanner";
import { PlayerControls } from "../PlayerControls";
import { SideNav } from "../SideNav";
import { UpNext } from "../UpNext";
import { ProgressLine } from "./ProgressLine";

export function CompactLayout({
  isUpNextOpen,
  onToggleUpNext,
  isNowPlayingOpen,
  onToggleNowPlaying,
}: {
  isUpNextOpen: boolean;
  onToggleUpNext: () => void;
  isNowPlayingOpen: boolean;
  onToggleNowPlaying: (open: boolean) => void;
}) {
  const { t } = useTranslation();
  const location = useLocation();
  const { currentTrack, queue, currentTrackIndex } = useQueue();
  const { data: album } = useAlbum(currentTrack?.albumId);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const isPanelOpen = isMenuOpen || isUpNextOpen;
  const hasUpcomingTracks = queue.length > currentTrackIndex + 1;

  const closePanels = () => {
    setIsMenuOpen(false);
    if (isUpNextOpen) onToggleUpNext();
  };

  // Close the menu after navigating somewhere
  // biome-ignore lint/correctness/useExhaustiveDependencies(location.pathname): suppress location.pathname
  useEffect(() => {
    setIsMenuOpen(false);
  }, [location.pathname]);

  // Escape should close open panels
  useEffect(() => {
    if (!isPanelOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") closePanels();
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  });

  return (
    <div className="relative h-full flex flex-col overflow-hidden bg-page-bg">
      <div
        inert={isNowPlayingOpen || isPanelOpen}
        className="relative flex-1 min-h-0 flex flex-col"
      >
        <Outlet />
      </div>

      <div
        inert={isNowPlayingOpen || isPanelOpen}
        className="relative flex-shrink-0 flex items-center gap-3 px-4 py-2 overflow-hidden text-white select-none"
      >
        <BlurredArtwork />

        <ProgressLine className="absolute top-0 inset-x-0" />

        <button
          type="button"
          onClick={() => setIsMenuOpen(true)}
          className="relative grid place-items-center size-9 flex-shrink-0 rounded-full cursor-pointer hover:bg-white/10"
        >
          <MenuIcon
            className="size-5"
            title={t("button.openMenu", { defaultValue: "Menu" })}
          />
        </button>

        <button
          type="button"
          disabled={!currentTrack}
          onClick={() => onToggleNowPlaying(true)}
          className="relative flex-1 min-w-0 flex items-center gap-3 text-left cursor-pointer disabled:cursor-default"
        >
          <AlbumArtwork
            album={album}
            size="thumbnail"
            className="size-10 flex-shrink-0 rounded-md shadow-md shadow-black/30 bg-linear-to-tl from-stone-600 to-stone-700"
            style={{
              viewTransitionName: isNowPlayingOpen
                ? undefined
                : "now-playing-artwork",
            }}
          />
          <div className="min-w-0">
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
                  currentTrack?.artist?.name ||
                  t("player.noTrack.artistName", {
                    defaultValue: "No Artist",
                  })
                }
              />
            </div>
          </div>
        </button>

        <div className="relative flex-shrink-0">
          <PlayerControls />
        </div>

        <button
          type="button"
          onClick={onToggleUpNext}
          className={classNames([
            "relative grid place-items-center size-9 flex-shrink-0 rounded-full cursor-pointer hover:bg-white/10",
            isUpNextOpen ? "text-white" : "text-white/60",
          ])}
        >
          <UpNextIcon
            className="size-4"
            title={t("button.showUpNext", { defaultValue: "Up Next" })}
          />
        </button>
      </div>

      <div
        className={classNames([
          "absolute inset-0 z-30 bg-black/30 transition-opacity duration-300",
          isPanelOpen ? "opacity-100" : "opacity-0 pointer-events-none",
        ])}
        onClick={closePanels}
        aria-hidden
      />

      <div
        inert={!isMenuOpen || isNowPlayingOpen}
        className={classNames([
          "absolute z-30 inset-y-0 left-0 w-72 py-5 px-3 flex flex-col gap-3 bg-sidenav-bg",
          "transition-transform duration-300 ease-out",
          isMenuOpen ? "translate-x-0 shadow-2xl" : "-translate-x-full",
        ])}
      >
        <div className="flex-shrink-0">
          <SideNav />
        </div>
        <NoticeBanner className="flex-shrink-0" />
      </div>

      <div
        inert={!isUpNextOpen || isNowPlayingOpen}
        className={classNames([
          "absolute z-30 inset-y-0 right-0 w-80 pt-5 px-3 flex flex-col overflow-hidden text-white select-none",
          "transition-transform duration-300 ease-out",
          isUpNextOpen ? "translate-x-0 shadow-2xl" : "translate-x-full",
        ])}
      >
        <BlurredArtwork />
        {!hasUpcomingTracks && (
          <strong className="relative my-2 px-2 text-xs font-semibold">
            {t("upNext.title", { defaultValue: "Up Next" })}
          </strong>
        )}
        <div className="relative flex-1 min-h-0 flex flex-col">
          <UpNext isVisible={true} animateHeight={false} />
        </div>
      </div>

      {isNowPlayingOpen && (
        <FullPlayer onClose={() => onToggleNowPlaying(false)} />
      )}
    </div>
  );
}
