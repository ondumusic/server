export type UUID = string;

export interface Artist {
  __type: "artist";
  id: UUID;
  name: string;
  slug: string;
  albumCount: number;
}

export interface Album {
  __type: "album";
  id: UUID;
  artistId: UUID;
  name: string;
  slug: string;
  releaseYear: number;
  tracks: Track[];
  isUnknown: boolean;
  artworkUrl?: string;
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
}

export interface Disc {
  number: number;
  tracks: Track[];
}

export interface Page<T> {
  __type: "page";
  __subtype: "artist" | "album";
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
