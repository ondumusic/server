import type { ListItem as DefaultListItem } from "../../components/SelectableList";
import type { Album, Track } from "../../types";

export type TrackItem = DefaultListItem & {
  type: "track";
  track: Track;
};

export type HeaderItem = DefaultListItem & {
  type: "header";
  album: Album;
  tracks: Track[];
};

export type ListItem = HeaderItem | TrackItem;
