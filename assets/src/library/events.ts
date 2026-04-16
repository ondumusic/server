export type ChangeSource = "local" | "broadcast";

export type ChangeDetail = {
  source: ChangeSource;
};

export type ChangeListener = (detail: ChangeDetail) => void;

// Ideally we use a broadcast channel to update all tabs of same origin.
const broadcast =
  typeof BroadcastChannel !== "undefined"
    ? new BroadcastChannel("musicbox-sync")
    : null;

broadcast?.addEventListener("message", (e) => {
  if (e.data?.type === "sync-complete") {
    for (const store of e.data.stores) {
      emit(store, { source: "broadcast" });
    }
  }
});

const listeners = new Map<string, Set<ChangeListener>>();

const emit = (store: string, detail: ChangeDetail = { source: "local" }) => {
  for (const callback of listeners.get(store) ?? []) callback(detail);
};

export const subscribe = (
  store: string,
  callback: ChangeListener,
): (() => void) => {
  if (!listeners.has(store)) listeners.set(store, new Set());
  listeners.get(store)?.add(callback);
  return () => listeners.get(store)?.delete(callback);
};

// Notify locally + tell other tabs which stores changed
export const notifyChanges = (stores: string[]) => {
  for (const store of stores) emit(store, { source: "local" });
  broadcast?.postMessage({ type: "sync-complete", stores });
};
