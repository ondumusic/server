export type UUID = string;

export interface AlbumArtist {
  id: UUID;
  name: string;
  slug: string;
  albumCount: number;
}

export interface Artist {
  id: UUID;
  name: string;
}

export interface Album {
  id: UUID;
  albumArtistId: UUID;
  name: string;
  releaseYear: number;
  songs: Song[];
}

export interface Song {
  id: UUID;
  artistId: UUID;
  albumId: UUID;
  albumArtistId: UUID;
  artist: Artist;
  name: string;
  disc: number;
  track: number;
  duration: number;
}

export interface Disc {
  number: number;
  songs: Song[];
}

export interface Page<T> {
  pageNumber: number;
  pageSize: number;
  totalPages: number;
  totalEntries: number;
  entries: T[];
}
