import { memo } from "react";
import { Trans } from "react-i18next";
import type { ListItem as DefaultListItem } from "../components/SelectableList";
import type { Playlist, Track } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";

type PlaylistHeaderItem = DefaultListItem & {
  type: "playlist";
  playlist: Playlist;
};

type TrackItem = DefaultListItem & {
  type: "track";
  number: number;
  track: Track;
  lastTrack?: boolean;
};

export type ListItem = PlaylistHeaderItem | TrackItem;

interface Props {
  item: ListItem;
  isSelected: boolean;
  isDragging?: boolean;
}

export const PlaylistItem = memo(({ item, isSelected }: Props) => {
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
            >
              {{ count: item.playlist.trackCount }} tracks
            </Trans>
          </span>
        </header>
      );

    case "track":
      return (
        <div
          className={classNames([
            "flex w-full items-center h-12 gap-2 text-sm py-1.5 @md:px-2 gap-4 group/track",

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
          {item.track?.album?.artworkUrl ? (
            <img
              src={item.track?.album?.artworkUrl}
              alt=""
              className="w-8 aspect-square object-cover object-center lg:rounded-sm overflow-hidden lg:shadow-sm "
            />
          ) : (
            <div className="w-8 aspect-square bg-linear-to-tl from-mist-600 to-mist-700 lg:rounded-sm lg:shadow-sm "></div>
          )}

          <span
            className={classNames([
              "w-4 @md:w-6 flex-shrink-0 font-light text-right tabular-nums",
              !isSelected && "text-panel-fg-muted",
            ])}
          >
            {item.number && `${item.number}.`}
          </span>

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
});
