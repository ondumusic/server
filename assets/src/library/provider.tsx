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
  const [pageLoadSync, setPageLoadSync] = useState(true);
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
      setPageLoadSync(false);
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
      {pageLoadSync ? <Loading /> : children}
    </LibraryContext.Provider>
  );
}

export function useLibrary() {
  const ctx = useContext(LibraryContext);
  if (!ctx) throw new Error("useLibrary must be used inside <LibraryProvider>");
  return ctx;
}
