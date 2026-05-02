import type {
  Album,
  Artist,
  Playlist,
  PlaylistItem,
  Track,
  UUID,
} from "../types";
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
      tracks: (albums: Album[]): JoinQuery<Track, Album> => {
        const albumIds = new Set(albums.map((album) => album.id));

        return {
          store: "tracks",
          references: "albumId",
          cardinality: "many",
          whereIndex: ["by_albumArtistId", "=", artistId],
          having: {
            albumId: (albumId: UUID) => albumIds.has(albumId),
          },
          sortBy: [
            ["disc", "asc"],
            ["number", "asc"],
          ],
        };
      },
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
  playlistId?: UUID;
  random?: boolean;
}

export const queryTracks = (filters: TrackFilters) => {
  if (filters.playlistId) {
    const query: Query<PlaylistItem> = {
      whereIndex: ["by_playlistId", "=", filters.playlistId],
      sortBy: filters.random === true ? "random" : [["position", "asc"]],
      join: {
        track: (playlistItems: PlaylistItem[]): JoinQuery<Track, PlaylistItem> => {
          const trackIds = new Set(playlistItems.map((item) => item.trackId));

          return {
            store: "tracks",
            foreignKey: "trackId",
            cardinality: "one",
            having: {
              id: (trackId: UUID) => trackIds.has(trackId),
            },
          };
        },
      },
    };

    return repo
      .query<PlaylistItem>("playlistItems", query)
      .then((playlistItems) => {
        return playlistItems
          .map((item) => item.track)
          .filter((track) => track !== null);
      }) as Promise<Track[]>;
  }

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

export const queryTracksByIds = (trackIds: UUID[]) => {
  return repo.getMany<Track>("tracks", trackIds);
};

// List Playlists
export const queryPlaylists = ({
  includeAll = false,
  parentId,
}: {
  includeAll?: boolean;
  parentId?: UUID;
}) => {
  let query: Query<Playlist> = {
    sortBy: [
      ["isFolder", "desc"],
      ["name", "asc"],
    ],
  };

  if (!includeAll) {
    query = {
      ...query,
      having: {
        hasParent: ["=", "NO"],
      },
    };
  }

  if (parentId) {
    query = { ...query, whereIndex: ["by_parentId", "=", parentId] };
  }

  return repo.query<Playlist>("playlists", query);
};

export function usePlaylists(query = {}) {
  return useStoreQuery<Playlist>("playlists", () => queryPlaylists(query));
}

// List Playlist Items
export const queryPlaylistsItems = (playlistId: UUID) => {
  const query: Query<PlaylistItem> = {
    whereIndex: ["by_playlistId", "=", playlistId],
    sortBy: [["position", "asc"]],
    join: {
      track: (playlistItems: PlaylistItem[]): JoinQuery<Track, PlaylistItem> => {
        const trackIds = new Set(playlistItems.map((item) => item.trackId));

        return {
          store: "tracks",
          foreignKey: "trackId",
          cardinality: "one",
          having: {
            id: (trackId: UUID) => trackIds.has(trackId),
          },
          join: {
            album: (tracks: Track[]): JoinQuery<Album, Track> => {
              const albumIds = new Set(tracks.map((item) => item.albumId));

              return {
                store: "albums",
                foreignKey: "albumId",
                cardinality: "one",
                having: {
                  id: (albumId: UUID) => albumIds.has(albumId),
                },
              };
            },
          },
        };
      },
    },
  };

  return repo.query<PlaylistItem>("playlistItems", query);
};

export function usePlaylistItems(playlistId: UUID) {
  return useStoreQuery<PlaylistItem>(
    "playlistItems",
    () => queryPlaylistsItems(playlistId),
    [playlistId],
  );
}

// Playlist details
export const queryPlaylist = (playlistId: UUID) =>
  repo.get<Playlist>("playlists", playlistId);

export function usePlaylist(playlistId: UUID | undefined) {
  return useStoreRecord<Playlist>(
    "playlists",
    () => queryPlaylist(playlistId as UUID),
    [playlistId],
    {
      enabled: !!playlistId,
    },
  );
}

export const queryPlaylistItemsByIds = async (playlistItemIds: UUID[]) => {
  const items = await repo.getMany<PlaylistItem>(
    "playlistItems",
    playlistItemIds,
  );
  const trackIds = new Set(items.map((item) => item.trackId));
  const tracks = await queryTracksByIds(Array.from(trackIds));
  return items.map((item) => ({
    ...item,
    track: tracks.find((track) => track.id === item.trackId),
  }));
};
