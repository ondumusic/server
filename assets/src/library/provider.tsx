import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { useTranslation } from "react-i18next";

import { Loading } from "../components/Loading";
import { useAuth } from "../hooks/useAuth";

import { type SyncProgress, sync } from "./sync";

const FIVE_MINUTES = 5 * 60 * 1000;

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

export function LibraryProvider({ children }: PropsWithChildren) {
  const { t } = useTranslation();
  const { isLoggedIn } = useAuth();
  const [pageLoadSync, setPageLoadSync] = useState(isLoggedIn);
  const [syncing, setSyncing] = useState(true);
  const [lastSynced, setLastSynced] = useState<Date | undefined>(undefined);
  const [syncError, setSyncError] = useState<unknown | undefined>(undefined);
  const [syncProgress, setSyncProgress] = useState<SyncProgress | undefined>(
    undefined,
  );
  const syncLock = useRef(false);

  const doSync = useCallback(async () => {
    if (!isLoggedIn) return;
    if (syncLock.current || !navigator.onLine) return;
    syncLock.current = true;
    setSyncing(true);
    setSyncError(undefined);

    try {
      await sync.startSync();
      setLastSynced(new Date());
    } catch (error) {
      setSyncError(error);
    } finally {
      setSyncing(false);
      setPageLoadSync(false);
      syncLock.current = false;
    }
  }, [isLoggedIn]);

  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState !== "visible") return;

      if (!lastSynced || Date.now() - lastSynced.getTime() > FIVE_MINUTES) {
        doSync();
      }
    };
    const onOnline = () => {
      if (!lastSynced || Date.now() - lastSynced.getTime() > FIVE_MINUTES) {
        doSync();
      }
    };
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("online", onOnline);
    return () => {
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("online", onOnline);
    };
  }, [doSync, lastSynced]);

  // Sync when logged in
  // biome-ignore lint/correctness/useExhaustiveDependencies(doSync): suppress dependency
  useEffect(() => {
    if (!isLoggedIn) return;

    sync.getLastSyncedAt().then((lastSyncedAt?: Date) => {
      setPageLoadSync(!lastSyncedAt);
      doSync();
    });
  }, [isLoggedIn]);

  // Monitor sync progress
  useEffect(() => {
    const unsubscribe = sync.addObserver(setSyncProgress);
    return unsubscribe;
  }, []);

  return (
    <LibraryContext.Provider value={{ syncing, lastSynced, syncError, doSync }}>
      {isLoggedIn && pageLoadSync ? (
        <Loading>
          <p className="text-center py-6 text-xs">
            {t("sync.progressText", {
              defaultValue: "Syncing library...",
              artistCount: syncProgress?.artists ?? 0,
              albumCount: syncProgress?.albums ?? 0,
              trackCount: syncProgress?.tracks ?? 0,
            })}
          </p>
        </Loading>
      ) : (
        children
      )}
    </LibraryContext.Provider>
  );
}

export function useLibrary() {
  const ctx = useContext(LibraryContext);
  if (!ctx) throw new Error("useLibrary must be used inside <LibraryProvider>");
  return ctx;
}
