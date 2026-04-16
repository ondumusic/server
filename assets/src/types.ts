export type UUID = string;

export type OnboardingStep = "user" | "settings" | null;

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
  };
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

  artistName?: string;
  artistSortName?: string;
  insertedAt?: Date | string | number;
}

export namespace Album {
  export type Indexes = {
    by_slug: string;
    by_artistId: string;
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
  albumName?: string;
  albumArtistName?: string;
  insertedAt?: Date | string | number;
}

export namespace Track {
  export type Indexes = {
    by_artistId: UUID;
    by_albumId: UUID;
    by_albumArtistId: UUID;
  };
}

export interface Disc {
  number: number;
  tracks: Track[];
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
