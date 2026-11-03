import { useSyncExternalStore } from "react";

const ARTIST_PHOTOS_KEY = "showArtistPhotos";

type Listener = () => void;

export class AppearanceService {
  #listeners = new Set<Listener>();

  get showArtistPhotos(): boolean {
    return localStorage.getItem(ARTIST_PHOTOS_KEY) !== "false";
  }

  set showArtistPhotos(show: boolean) {
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
  const showArtistPhotos = useSyncExternalStore(
    (listener) => appearance.subscribe(listener),
    () => appearance.showArtistPhotos,
  );

  return { showArtistPhotos };
}
