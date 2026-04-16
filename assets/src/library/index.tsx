import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";

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
  const [syncing, setSyncing] = useState(false);
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
    doSync();
  }, [doSync]);

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

  return (
    <LibraryContext.Provider value={{ syncing, lastSynced, syncError, doSync }}>
      {children}
    </LibraryContext.Provider>
  );
}

export function useLibrary() {
  const ctx = useContext(LibraryContext);
  if (!ctx) throw new Error("useLibrary must be used inside <LibraryProvider>");
  return ctx;
}

import type { Artist } from "../types";
import { repo } from "./repo";

export function useArtists() {
  const [data, setData] = useState<Artist[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);

  const queryRef = useRef(() =>
    repo.query<Artist, Artist.Indexes>("artists", {
      whereIndex: ["filter_albumCount", ">", 0],
      sortDir: "asc",
      sortBy: "sortName",
    }),
  );

  const load = useCallback(async () => {
    if (!queryRef.current) return;

    try {
      const results = await queryRef.current();
      setData(results);
      setError(null);
    } catch (err) {
      console.error("Query failed:", err);
      setError(err);
    } finally {
      setLoading(false);
    }
  }, []);

  // // Subscribe to change events from all relevant stores
  // useEffect(() => {
  //   load();
  //   const unsubs = storeNames.map((name) => subscribe(name, load));
  //   return () => unsubs.forEach((u) => u());
  // }, [load, ...storeNames]);

  // Re-query when deps change (e.g. filters)
  // const depKey = JSON.stringify(deps);
  useEffect(() => {
    setLoading(true);
    load();
  }, [load]);
  // }, [depKey, load]);

  return { data, loading, error };
}
