import { memo } from "react";
import { Trans, useTranslation } from "react-i18next";
import { AnimatedWaveform } from "../components/icons/AnimatedWaveform";
import { PlayIcon } from "../components/icons/PlayIcon";
import type { ListItem as DefaultListItem } from "../components/SelectableList";
import type { Playlist, PlaylistItem as TPlaylistItem, Track } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";
import { formatTotalDuration } from "../utils/formatTotalDuration";

type PlaylistHeaderItem = DefaultListItem & {
  type: "playlist";
  playlist: Playlist;
  totalDuration: number;
};

type TrackItem = DefaultListItem & {
  type: "track";
  number: number;
  track: Track;
  item: TPlaylistItem;
  lastTrack?: boolean;
};

export type ListItem = PlaylistHeaderItem | TrackItem;

interface Props {
  item: ListItem;
  isSelected: boolean;
  isPlaying?: boolean;
  isDragging?: boolean;
}

export const PlaylistItem = memo(
  ({ item, isDragging, isPlaying, isSelected }: Props) => {
    const { t } = useTranslation();

    switch (item.type) {
      case "playlist":
        return (
          <header className="mt-18 md:mt-4 lg:mt-8 @md:mb-4 @md:pb-4 @md:border-b border-panel-fg-divider">
            <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
              {item.playlist.name}
            </h1>
            <span className="text-sm text-panel-fg-muted">
              <Trans
                i18nKey="playlist.trackCount"
                count={item.playlist.trackCount}
                duration={formatTotalDuration(item.totalDuration)}
              >
                {{ count: item.playlist.trackCount }} tracks,{" "}
                {{ duration: formatTotalDuration(item.totalDuration) }}
              </Trans>
            </span>
          </header>
        );

      case "track":
        return (
          <div
            className={classNames([
              "flex w-full items-center h-12 gap-2 text-sm py-1.5 @md:px-2 gap-4 group/track",
              isDragging && "opacity-50",
              isSelected &&
                "bg-blue-400 [.selectable-list:focus_&]:bg-blue-500 text-white",
              isSelected && "rounded-t-md rounded-b-md",
              isSelected &&
                "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
              isSelected &&
                "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
              "border-b",
              item.lastTrack || isSelected
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
              {item.number && `${item.number}.`}
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
                    trackName: item.track.name,
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
                    trackName: item.track.name,
                  })}
                />
              )}
            </div>

            {item.track?.album?.artworkUrl ? (
              <div
                className="w-8 h-8 overflow-hidden bg-contain bg-center lg:rounded-sm overflow-hidden lg:shadow-sm "
                style={{
                  backgroundImage: `url(${item.track?.album?.artworkUrl})`,
                }}
              />
            ) : (
              <div className="w-8 h-8 overflow-hidden bg-linear-to-br from-stone-50 to-stone-200 lg:rounded-sm lg:shadow-sm "></div>
            )}

            <div>
              <div
                className={classNames(["w-full", "line-clamp-1"])}
                title={item.track.name}
              >
                {item.track.name}
              </div>

              <div
                className={classNames([
                  "w-full line-clamp-1",
                  !isSelected && "text-panel-fg-muted",
                ])}
                title={item.track.artistName}
              >
                {item.track.artistName}
              </div>
            </div>

            <span
              className={classNames([
                "ml-auto font-light flex-shrink-0 tabular-nums",
                !isSelected && "text-panel-fg-muted",
              ])}
            >
              {formatDuration(item.track.duration)}
            </span>
          </div>
        );
    }
  },
);
