export type UUID = string;

export type OnboardingStep = "user" | "settings" | null;

type One<E> = { entity: E; cardinality: "one" };
type Many<E> = { entity: E; cardinality: "many" };

export interface RouteContext {
  auth: {
    isLoggedIn: boolean;
    currentUser?: User;
  };
  onboarding: {
    step: OnboardingStep;
    setStep(step: OnboardingStep): void;
  };
}

export interface Artist {
  __type: "artist";
  id: UUID;
  name: string;
  slug: string;
  albumCount: number;

  sortName?: string;
  insertedAt?: Date | string | number;
}

export namespace Artist {
  export type Indexes = {
    by_slug: string;
    filter_albumCount: number;
    by_missingData: "YES" | "NO";
  };
}

export interface Album {
  __type: "album";
  id: UUID;
  artistId: UUID;
  name: string;
  sortName: string;
  slug: string;
  releaseYear: number;
  tracks: Track[];
  isUnknown: boolean;
  artworkUrl?: string;

  artistName?: string;
  artistSortName?: string;
  insertedAt?: Date | string | number;
}

export namespace Album {
  export type Indexes = {
    by_slug: string;
    by_artistId: UUID;
    by_missingData: "YES" | "NO";
  };
  export type Joins = {
    artist: One<Artist>;
    tracks: Many<Track>;
  };
}

export interface Track {
  __type: "track";
  id: UUID;
  artistId: UUID;
  albumArtistId: UUID;
  albumId: UUID;
  artist: Artist;
  name: string;
  disc: number;
  number: number;
  duration: number;
  mimetype: string;
  streamUrl: string;

  artistName?: string;
  artistSortName?: string;
  album?: Album;
  albumName?: string;
  albumArtistName?: string;
  albumArtistSortName?: string;
  albumReleaseYear?: number;
  insertedAt?: Date | string | number;
}

export namespace Track {
  export type Indexes = {
    by_artistId: UUID;
    by_albumId: UUID;
    by_albumArtistId: UUID;
    by_missingData: "YES" | "NO";
  };
  export type Joins = {
    album: One<Album>;
  };
}

export interface Disc {
  number: number;
  tracks: Track[];
}

export interface Playlist {
  __type: "playlist";
  id: UUID;
  parentId: UUID;
  name: string;
  isFolder: boolean;
  hasParent: "YES" | "NO";
  trackCount: number;
  insertedAt?: Date | string | number;
}

export namespace Playlist {
  export type Indexes = {
    by_hasParent: "YES" | "NO";
    by_parentId: UUID;
    by_missingData: "YES" | "NO";
  };
  export type Joins = {
    parent: One<Playlist>;
    items: Many<PlaylistItem>;
  };
}

export interface PlaylistItem {
  __type: "playlistItem";
  id: UUID;
  playlistId: UUID;
  position: string;
  trackId: UUID;
  track?: Track;
  insertedAt?: Date | string | number;
}

export namespace PlaylistItem {
  export type Indexes = {
    by_playlistId: UUID;
    by_missingData: "YES" | "NO";
  };
  export type Joins = {
    playlist: One<Playlist>;
    track: One<Track>;
  };
}

export interface Page<T> {
  __type: "page";
  __subtype: "artist" | "album" | "track";
  pageNumber: number;
  pageSize: number;
  totalPages: number;
  totalEntries: number;
  entries: T[];
}

export interface User {
  id: UUID;
  username: string;
}

export type ScanType = "full" | "quick";

export interface Settings {
  musicPath: string;
  scanType: ScanType;
  pollInterval: number;
}

export type Stats = {
  artists: number;
  albums: number;
  tracks: number;
  playlists: number;
};

export type IndexesOf<T> = T extends Artist
  ? Artist.Indexes
  : T extends Album
    ? Album.Indexes
    : T extends Track
      ? Track.Indexes
      : T extends Playlist
        ? Playlist.Indexes
        : T extends PlaylistItem
          ? PlaylistItem.Indexes
          : never;

export type JoinsOf<T> = T extends Album
  ? Album.Joins
  : T extends Track
    ? Track.Joins
    : T extends Playlist
      ? Playlist.Joins
      : T extends PlaylistItem
        ? PlaylistItem.Joins
        : never;
