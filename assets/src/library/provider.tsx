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
import { useMediaQuery } from "../hooks/useMediaQuery";
import type { OnboardingStep } from "../types";

import { maybeReindexSearch } from "./search";
import { type SyncProgress, sync } from "./sync";

const FIVE_MINUTES = 5 * 60 * 1000;

declare var hydrateReact: { onboarding: OnboardingStep };

const isOnboarding = !!hydrateReact.onboarding;

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
  // Same as the CompactLayout breakpoint in _authenticated.tsx
  const isSupportedScreen = useMediaQuery("(width >= 46rem)");
  const [pageLoadSync, setPageLoadSync] = useState<boolean | undefined>(
    isOnboarding ? false : undefined,
  );
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

    maybeReindexSearch();

    sync.getLastSyncedAt().then((lastSyncedAt?: Date) => {
      setPageLoadSync(!lastSyncedAt && !isOnboarding);
      doSync();
    });
  }, [isLoggedIn]);

  // Monitor sync progress
  useEffect(() => {
    const unsubscribe = sync.addObserver(setSyncProgress);
    return unsubscribe;
  }, []);

  // As a quick hack we'll avoid showing the sync status on small screens
  // because otherwise their experience is seeing a sync and then the
  // message saying small screen not supported yet. I don't want to hack
  // around to make the actual sync conditional either so hacky solution it is.
  const showSyncScreen = pageLoadSync && isSupportedScreen;

  return (
    <LibraryContext.Provider value={{ syncing, lastSynced, syncError, doSync }}>
      {isLoggedIn && pageLoadSync === undefined ? (
        <Loading fullPage />
      ) : isLoggedIn && showSyncScreen ? (
        <Loading fullPage>
          <p className="text-center py-6 text-xs transition-opacity duration-500 starting:opacity-0">
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
