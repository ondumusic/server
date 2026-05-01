import { memo } from "react";
import { Trans } from "react-i18next";
import type { ListItem as DefaultListItem } from "../components/SelectableList";
import type { Playlist, Track } from "../types";

type PlaylistHeaderItem = DefaultListItem & {
  type: "playlist";
  playlist: Playlist;
};

type TrackItem = DefaultListItem & {
  type: "track";
  number: number;
  track: Track;
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
        <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 @md:border-b border-panel-fg-divider">
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
        <div className="flex gap-4">
          <div>
            {item.number}. {item.track.name}
            {isSelected && " -- SELECTED"}
          </div>
        </div>
      );
  }
});
