import { useTranslation } from "react-i18next";
import { AnimatedWaveform } from "../../components/icons/AnimatedWaveform";
import { PlayIcon } from "../../components/icons/PlayIcon";
import type { Track } from "../../types";
import { classNames } from "../../utils/classNames";
import { formatDuration } from "../../utils/formatDuration";

interface Props {
  track: Track;
  number: number;
  isSelected: boolean;
  isDragging: boolean;
  isPlaying: boolean;
  isLastTrack: boolean;
  showTrackArtist?: boolean;
  showAlbumArtwork?: boolean;
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
}: Props) {
  const { t } = useTranslation();

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
            : "border-panel-fg-divider",
        ])}
      >
        <span
          className={classNames([
            "w-4 @md:w-6 flex-shrink-0 font-light text-right tabular-nums",
            "group-hover/track:hidden",
            !isSelected && "text-panel-fg-muted",
            isPlaying && "hidden",
          ])}
        >
          {number && `${number}.`}
        </span>

        <div
          className={classNames([
            "w-4 @md:w-6 group-hover/track:flex justify-end flex-shrink-0",
            !isPlaying ? "hidden" : "flex",
          ])}
        >
          {isPlaying ? (
            <AnimatedWaveform
              className={classNames([
                "size-3 text-accent-500",
                isSelected && "text-white",
              ])}
              title={t("button.playSelectedTrack", {
                defaultValue: "Play {{ trackName }}",
                trackName: track.name,
              })}
            />
          ) : (
            <PlayIcon
              className={classNames([
                "size-3 text-accent-500",
                isSelected && "text-white",
              ])}
              title={t("button.playSelectedTrack", {
                defaultValue: "Play {{ trackName }}",
                trackName: track.name,
              })}
            />
          )}
        </div>

        {showAlbumArtwork && track?.album?.artworkUrl ? (
          <div
            className="w-8 h-8 overflow-hidden bg-contain bg-center lg:rounded-sm overflow-hidden lg:shadow-sm flex-shrink-0"
            style={{
              backgroundImage: `url(${track?.album?.artworkUrl})`,
            }}
          />
        ) : (
          <div
            className={classNames([
              "w-8 h-8 overflow-hidden bg-linear-to-br from-stone-50 to-stone-200 lg:rounded-sm lg:shadow-sm flex-shrink-0",
              !showAlbumArtwork && "hidden",
            ])}
          ></div>
        )}

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
                !isSelected && "text-panel-fg-muted",
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
            !isSelected && "text-panel-fg-muted",
          ])}
        >
          {formatDuration(track.duration)}
        </span>
      </div>
    </div>
  );
}
