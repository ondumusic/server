import type { ListItem as DefaultListItem } from "../../components/SelectableList";
import type { Album, Disc, Track } from "../../types";

export type DiscItem = DefaultListItem & {
  type: "disc";
  disc: Disc;
};

export type PlaceholderItem = DefaultListItem & {
  type: "placeholder";
};

export type TrackItem = DefaultListItem & {
  type: "track";
  track: Track;
  showTrackArtist: boolean;
  lastTrackOnDisc: boolean;
};

export type HeaderItem = DefaultListItem & {
  type: "header";
  album: Album;
  tracks: Track[];
};

export type ListItem = HeaderItem | DiscItem | TrackItem | PlaceholderItem;
