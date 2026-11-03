import { useSyncExternalStore } from "react";

const ARTIST_PHOTOS_KEY = "showArtistArtwork";

type Listener = () => void;

export class AppearanceService {
  #listeners = new Set<Listener>();

  get showArtistArtwork(): boolean {
    return localStorage.getItem(ARTIST_PHOTOS_KEY) !== "false";
  }

  set showArtistArtwork(show: boolean) {
    localStorage.setItem(ARTIST_PHOTOS_KEY, String(show));
    this.#notify();
  }

  subscribe(listener: Listener): () => void {
    this.#listeners.add(listener);
    return () => this.#listeners.delete(listener);
  }

  #notify() {
    for (const listener of this.#listeners) listener();
  }
}

export const appearance = new AppearanceService();

export function useAppearance() {
  const showArtistArtwork = useSyncExternalStore(
    (listener) => appearance.subscribe(listener),
    () => appearance.showArtistArtwork,
  );

  return { showArtistArtwork };
}
