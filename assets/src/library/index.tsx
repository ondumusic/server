import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";

import { Loading } from "../components/Loading";

import { sync } from "./sync";

export interface LibraryContext {
  syncing: boolean;
  lastSynced?: Date;
  syncError?: unknown;
  doSync: () => void;
}

const LibraryContext = createContext<LibraryContext>({
  syncing: false,
  lastSynced: undefined,
  syncError: undefined,
  doSync: () => {},
});

export function LibraryProvider({
  children,
  pollInterval = undefined,
}: PropsWithChildren<{
  pollInterval?: number;
}>) {
  const [syncing, setSyncing] = useState(true);
  const [lastSynced, setLastSynced] = useState<Date | undefined>(undefined);
  const [syncError, setSyncError] = useState<unknown | undefined>(undefined);
  const syncLock = useRef(false);

  const doSync = useCallback(async () => {
    if (syncLock.current || !navigator.onLine) return;
    syncLock.current = true;
    setSyncing(true);
    setSyncError(undefined);

    try {
      await sync.startSync();
      setLastSynced(new Date());
    } catch (err) {
      console.error("Sync error:", err);
      setSyncError(err);
    } finally {
      setSyncing(false);
      syncLock.current = false;
    }
  }, []);

  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === "visible") doSync();
    };
    const onOnline = () => doSync();
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("online", onOnline);
    return () => {
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("online", onOnline);
    };
  }, [doSync]);

  useEffect(() => {
    if (!pollInterval) return;
    const id = setInterval(doSync, pollInterval);
    return () => clearInterval(id);
  }, [doSync, pollInterval]);

  // Sync on component mount
  // biome-ignore lint/correctness/useExhaustiveDependencies(doSync): suppress dependency
  useEffect(() => {
    doSync();
  }, []);

  return (
    <LibraryContext.Provider value={{ syncing, lastSynced, syncError, doSync }}>
      {syncing ? <Loading /> : children}
    </LibraryContext.Provider>
  );
}

export function useLibrary() {
  const ctx = useContext(LibraryContext);
  if (!ctx) throw new Error("useLibrary must be used inside <LibraryProvider>");
  return ctx;
}

import type { Album, Artist, Track, UUID } from "../types";
import { isUUID } from "../utils/isUUID";
import { useStoreQuery, useStoreRecord } from "./hooks";
export function useArtists() {
  return useStoreQuery<Artist>("artists", (repo) =>
    repo.query<Artist, Artist.Indexes>("artists", {
      whereIndex: ["filter_albumCount", ">", 0],
      sortDir: "asc",
      sortBy: "sortName",
    }),
  );
}
export function useArtistAlbums(artistId: UUID) {
  return useStoreQuery<Album>(
    "albums",
    async (repo) => {
      const albums = await repo.query<Album, Album.Indexes>("albums", {
        whereIndex: ["by_artistId", "=", artistId],
        sortDir: "desc",
        sortBy: "releaseYear",
      });

      const albumIds = new Set(albums.map((a) => a.id));
      const tracks = await repo.query<Track, Track.Indexes>("tracks", {
        whereIndex: ["by_albumArtistId", "=", artistId],
        having: {
          albumId: (albumId: UUID) => albumIds.has(albumId),
        },
        sortBy: [
          ["disc", "asc"],
          ["number", "asc"],
        ],
      });

      const tracksByAlbumId = new Map<string, Track[]>();
      for (const track of tracks) {
        const arr = tracksByAlbumId.get(track.albumId) ?? [];
        arr.push(track);
        tracksByAlbumId.set(track.albumId, arr);
      }

      return albums.map((album) => ({
        ...album,
        tracks: tracksByAlbumId.get(album.id) ?? [],
      }));
    },
    [artistId],
  );
}
export function useArtist(idOrSlug: UUID | string) {
  return useStoreRecord<Artist>(
    "artists",
    (repo) =>
      isUUID(idOrSlug)
        ? repo.get<Artist>("artists", idOrSlug)
        : repo.getBy<Artist>("artists", "by_slug", idOrSlug),
    [idOrSlug],
  );
}
