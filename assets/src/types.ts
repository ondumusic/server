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
  artistId: UUID;
  name: string;
  releaseYear: number;
  tracks: Track[];
}

export interface Track {
  id: UUID;
  artistId: UUID;
  albumArtistId: UUID;
  albumId: UUID;
  artist: Artist;
  name: string;
  disc: number;
  number: number;
  duration: number;
}

export interface Disc {
  number: number;
  tracks: Track[];
}

export interface Page<T> {
  pageNumber: number;
  pageSize: number;
  totalPages: number;
  totalEntries: number;
  entries: T[];
}
