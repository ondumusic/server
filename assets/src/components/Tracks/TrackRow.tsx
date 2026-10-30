import type { MouseEvent as ReactMouseEvent } from "react";
import { useTranslation } from "react-i18next";
import { AnimatedWaveform } from "../../components/icons/AnimatedWaveform";
import { PlayIcon } from "../../components/icons/PlayIcon";
import type { Track } from "../../types";
import { classNames } from "../../utils/classNames";
import { formatDuration } from "../../utils/formatDuration";
import { AlbumArtwork } from "../AlbumArtwork";

interface Props {
  track: Track;
  number: number;
  isSelected: boolean;
  isDragging: boolean;
  isPlaying: boolean;
  isLastTrack: boolean;
  showTrackArtist?: boolean;
  showAlbumArtwork?: boolean;
  showNumber?: boolean;
}

const handlePlayClick = (e: ReactMouseEvent<HTMLButtonElement>) => {
  const listRowEl = e.currentTarget.closest("[data-item-id]");
  if (!listRowEl) return;
  listRowEl.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
};

function PlayButton({
  isPlaying,
  light,
  label,
}: {
  isPlaying: boolean;
  light: boolean;
  label: string;
}) {
  if (isPlaying)
    return (
      <AnimatedWaveform
        className={classNames([
          "size-4 text-accent-500",
          light && "text-white",
        ])}
        title={label}
      />
    );

  return (
    <button type="button" onClick={handlePlayClick}>
      <PlayIcon
        className={classNames([
          "size-4 text-accent-500",
          light && "text-white",
        ])}
        title={label}
      />
    </button>
  );
}

export function TrackRow({
  track,
  isSelected,
  isDragging,
  isPlaying,
  isLastTrack,
  number,
  showTrackArtist = true,
  showAlbumArtwork = true,
  showNumber = true,
}: Props) {
  const { t } = useTranslation();

  // The play/playing icon either shows instead of the number,
  // or over the artwork, depending on these props.
  const floatingPlayButton = !showNumber && showAlbumArtwork;

  return (
    <div className="group/track">
      <div
        className={classNames([
          "flex w-full items-center h-12 gap-4 text-sm py-1.5 @md:px-2",
          isDragging && "opacity-50",
          isSelected &&
            "bg-accent-400 [.selectable-list:focus_&]:bg-accent-500 text-white",
          isSelected && "rounded-t-md rounded-b-md",
          isSelected &&
            "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
          isSelected &&
            "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
          "border-b",
          isLastTrack || isSelected
            ? "border-transparent"
            : "border-page-fg-divider",
        ])}
      >
        {!floatingPlayButton && (
          <>
            <span
              className={classNames([
                "w-4 @md:w-6 flex-shrink-0 font-light text-right tabular-nums",
                "group-hover/track:hidden",
                !isSelected && "text-page-fg-muted",
                isPlaying && "hidden",
              ])}
            >
              {showNumber && number && `${number}.`}
            </span>

            <div
              className={classNames([
                "w-4 @md:w-6 group-hover/track:flex justify-end flex-shrink-0",
                !isPlaying ? "hidden" : "flex",
              ])}
            >
              <PlayButton
                isPlaying={isPlaying}
                light={isSelected}
                label={t("button.playSelectedTrack", {
                  defaultValue: "Play {{ trackName }}",
                  trackName: track.name,
                })}
              />
            </div>
          </>
        )}

        <AlbumArtwork
          album={track?.album}
          size="thumbnail"
          className={classNames([
            "w-8 h-8 bg-linear-to-br from-stone-50 to-stone-200 lg:rounded-sm lg:shadow-sm flex-shrink-0",
            !showAlbumArtwork && "hidden",
          ])}
        >
          {floatingPlayButton && (
            <div
              className={classNames([
                "absolute inset-0 items-center justify-center bg-black/50 lg:rounded-sm",
                "group-hover/track:flex",
                isPlaying ? "flex" : "hidden",
              ])}
            >
              <PlayButton
                isPlaying={isPlaying}
                light
                label={t("button.playSelectedTrack", {
                  defaultValue: "Play {{ trackName }}",
                  trackName: track.name,
                })}
              />
            </div>
          )}
        </AlbumArtwork>

        <div>
          <div
            className={classNames([
              "w-full",
              showTrackArtist ? "line-clamp-1" : "line-clamp-2",
            ])}
            title={track.name}
          >
            {track.name}
          </div>

          {showTrackArtist && (
            <div
              className={classNames([
                "w-full line-clamp-1",
                !isSelected && "text-page-fg-muted",
              ])}
              title={track.artistName}
            >
              {track.artistName}
            </div>
          )}
        </div>

        <span
          className={classNames([
            "ml-auto font-light flex-shrink-0 tabular-nums",
            !isSelected && "text-page-fg-muted",
          ])}
        >
          {formatDuration(track.duration)}
        </span>
      </div>
    </div>
  );
}
