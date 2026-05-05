import type { ListItem as DefaultListItem } from "../../components/SelectableList";
import type { Album, Artist, Disc, Track } from "../../types";

export type ArtistItem = DefaultListItem & {
  type: "artist";
  artist: Artist;
};

export type AlbumItem = DefaultListItem & {
  type: "album";
  album: Album;
  firstAlbumInList: boolean;
};

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

export type ListItem =
  | ArtistItem
  | AlbumItem
  | DiscItem
  | TrackItem
  | PlaceholderItem;
