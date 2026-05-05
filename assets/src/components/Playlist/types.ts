import type { ListItem as DefaultListItem } from "../../components/SelectableList";
import type { Playlist, PlaylistItem, Track } from "../../types";

export type HeaderItem = DefaultListItem & {
  type: "playlist";
  playlist: Playlist;
  totalDuration: number;
};

export type TrackItem = DefaultListItem & {
  type: "track";
  number: number;
  track: Track;
  item: PlaylistItem;
  lastTrack?: boolean;
};

export type ListItem = HeaderItem | TrackItem;
