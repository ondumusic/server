import type { Album, Artist, Track, UUID } from "../types";
import { isUUID } from "../utils/isUUID";
import { useStoreQuery, useStoreRecord } from "./hooks";
import { repo } from "./repo";
import type { JoinQuery, Query } from "./repo/queryHelpers";

// List Artists
export const queryArtists = () =>
  repo.query<Artist>("artists", {
    whereIndex: ["filter_albumCount", ">", 0],
    sortDir: "asc",
    sortBy: "sortName",
  });

export function useArtists() {
  return useStoreQuery<Artist>("artists", queryArtists);
}

// List Artist Albums
export const queryArtistAlbums = async (artistId: UUID) => {
  return await repo.query<Album>("albums", {
    whereIndex: ["by_artistId", "=", artistId],
    sortDir: "desc",
    sortBy: "releaseYear",
    join: {
      tracks: (albumIds: Set<UUID>): JoinQuery<Track> => ({
        store: "tracks",
        foreignKey: "albumId",
        cardinality: "many",
        whereIndex: ["by_albumArtistId", "=", artistId],
        having: {
          albumId: (albumId: UUID) => albumIds.has(albumId),
        },
        sortBy: [
          ["disc", "asc"],
          ["number", "asc"],
        ],
      }),
    },
  });
};

export function useArtistAlbums(artistId: UUID | undefined) {
  return useStoreQuery<Album>(
    "albums",
    () => queryArtistAlbums(artistId as UUID),
    [artistId],
    {
      enabled: !!artistId,
    },
  );
}

// Artist details
export const queryArtist = (idOrSlug: UUID | string) =>
  isUUID(idOrSlug)
    ? repo.get<Artist>("artists", idOrSlug)
    : repo.getBy<Artist>("artists", "by_slug", idOrSlug);

export function useArtist(idOrSlug: UUID | string) {
  return useStoreRecord<Artist>("artists", () => queryArtist(idOrSlug), [
    idOrSlug,
  ]);
}

// Album details
export const queryAlbum = (albumId: UUID) => repo.get<Album>("albums", albumId);

export function useAlbum(albumId: UUID | undefined) {
  return useStoreRecord<Album>(
    "albums",
    () => queryAlbum(albumId as UUID),
    [albumId],
    {
      enabled: !!albumId,
    },
  );
}

// List Tracks
interface TrackFilters {
  artistId?: UUID;
  albumId?: UUID;
  random?: boolean;
}

export const queryTracks = (filters: TrackFilters) => {
  let query: Query<Track> = {
    sortBy:
      filters.random === true
        ? "random"
        : [
            ["albumReleaseYear", "desc"],
            ["disc", "asc"],
            ["number", "asc"],
          ],
  };

  if (filters.artistId && filters.albumId) {
    query = {
      ...query,
      whereIndex: ["by_albumArtistId", "=", filters.artistId],
      having: {
        albumId: ["=", filters.albumId],
      },
    };
  } else if (filters.artistId) {
    query = {
      ...query,
      whereIndex: ["by_albumArtistId", "=", filters.artistId],
    };
  } else if (filters.albumId) {
    query = { ...query, whereIndex: ["by_albumId", "=", filters.albumId] };
  }

  return repo.query<Track>("tracks", query);
};

export function useTracks(filters: TrackFilters) {
  return useStoreQuery<Track>("tracks", () => queryTracks(filters), [filters]);
}
