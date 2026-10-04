import type { Notice } from "../api/notices";

type Listener = () => void;

// The active notices of the server. They originate from the sync responses,
// which always include any active service notices.
class NoticeStore {
  #notices: Notice[] = [];
  #listeners = new Set<Listener>();

  get = (): Notice[] => this.#notices;

  set(notices: Notice[]) {
    this.#notices = notices;
    for (const listener of this.#listeners) listener();
  }

  subscribe = (listener: Listener): (() => void) => {
    this.#listeners.add(listener);
    return () => this.#listeners.delete(listener);
  };
}

export const notices = new NoticeStore();
