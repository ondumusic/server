import { ClientError, client } from "../api";
import type { Album, Artist, Track } from "../types";
import { notifyChanges } from "./events";
import { repo } from "./repo";
import { transforms } from "./transforms";

interface SyncMeta<T> {
  key: string;
  value: T;
}

interface SyncDeletion {
  entityId: string;
  entityType: string;
}

interface SyncResponse {
  artists: Artist[];
  albums: Album[];
  tracks: Track[];
  deletions: SyncDeletion[];
  cursor: string;
  complete: boolean;
}

export interface SyncProgress {
  artists: number;
  albums: number;
  tracks: number;
}

type SyncProgressObserver = (progress: SyncProgress) => void;

class SyncClient {
  #syncing: boolean = false;
  #progress: SyncProgress = {
    artists: 0,
    albums: 0,
    tracks: 0,
  };
  #observers: Set<SyncProgressObserver> = new Set();

  constructor() {
    this.#resetProgress();
  }

  addObserver(observer: SyncProgressObserver): () => void {
    this.#observers.add(observer);
    return () => this.#observers.delete(observer);
  }

  async startSync() {
    if (this.#syncing) {
      throw new Error("failed to start sync, syncing already in progress");
    }

    this.#resetProgress();
    this.#emitProgress();
    this.#syncing = true;
    const cursor = await this.#getCursor();

    try {
      await this.#fetch(cursor);
      this.#setLastSyncedAt(new Date());
    } finally {
      this.#syncing = false;
    }
  }

  async pushChanges({
    artists = [],
    albums = [],
    tracks = [],
    deletions = [],
  }: {
    artists?: Artist[];
    albums?: Album[];
    tracks?: Track[];
    deletions?: SyncDeletion[];
  }) {
    // Process upserts
    await repo.putMany<Artist>("artists", await transforms.artists(artists));
    await repo.putMany<Album>("albums", await transforms.albums(albums));
    await repo.putMany<Track>("tracks", await transforms.tracks(tracks));

    // Process deletions
    const deletedEntitities = Map.groupBy(deletions, (e) => e.entityType);
    await repo.deleteMany(
      "artists",
      deletedEntitities.get("artist")?.map((d) => d.entityId) ?? [],
    );
    await repo.deleteMany(
      "albums",
      deletedEntitities.get("album")?.map((d) => d.entityId) ?? [],
    );
    await repo.deleteMany(
      "tracks",
      deletedEntitities.get("track")?.map((d) => d.entityId) ?? [],
    );

    // Check which stores changed and notify events
    const changedStores = new Set<string>();
    if (artists.length) changedStores.add("artists");
    if (albums.length) changedStores.add("albums");
    if (tracks.length) changedStores.add("tracks");
    if (deletedEntitities.get("artist")?.length) changedStores.add("artists");
    if (deletedEntitities.get("album")?.length) changedStores.add("albums");
    if (deletedEntitities.get("track")?.length) changedStores.add("tracks");
    if (changedStores.size > 0) notifyChanges([...changedStores]);

    this.#emitProgress();
    this.#prewarmArtwork(albums);
  }

  async #fetch(cursor?: string, attempt: number = 1) {
    try {
      const result = await client.get<undefined, SyncResponse>(`/sync`, {
        search: cursor ? { cursor } : {},
      });

      this.pushChanges(result);

      // Fetch next page unless completed.
      if (result.complete) {
        await this.#setCursor(result.cursor);
      } else {
        await this.#fetch(result.cursor);
      }
    } catch (error) {
      const abortedError = error instanceof ClientError && error.aborted;
      const clientError =
        error instanceof ClientError && (error.response?.status ?? 0) < 500;

      if (!abortedError && !clientError && attempt < 5) {
        await new Promise((resolve) => setTimeout(resolve, 1000));
        await this.#fetch(cursor, attempt + 1);
      }

      throw error;
    }
  }

  async #prewarmArtwork(albums: Album[]) {
    if (!albums.length) return;
    const urls = albums.map((album) => album.artworkUrl).filter((url) => !!url);
    const sw = await navigator.serviceWorker?.ready;
    if (sw?.active) {
      sw.active.postMessage({
        type: "PREWARM",
        urls,
      });
    }
  }

  async getLastSyncedAt() {
    const meta = await repo.get<SyncMeta<Date>>("meta", "sync-lastSyncedAt");
    return meta?.value;
  }

  async #setLastSyncedAt(lastSyncedAt: Date) {
    return await repo.put("meta", {
      key: "sync-lastSyncedAt",
      value: lastSyncedAt,
    });
  }

  async #getCursor() {
    const meta = await repo.get<SyncMeta<string>>("meta", "sync-cursor");
    return meta?.value;
  }

  async #setCursor(cursor: string) {
    return await repo.put("meta", { key: "sync-cursor", value: cursor });
  }

  #resetProgress() {
    this.#progress = {
      artists: 0,
      albums: 0,
      tracks: 0,
    };
  }

  async #emitProgress() {
    const counts = await Promise.all([
      await repo.count("artists"),
      await repo.count("albums"),
      await repo.count("tracks"),
    ]);

    this.#progress.artists = counts[0];
    this.#progress.albums = counts[1];
    this.#progress.tracks = counts[2];

    this.#observers.forEach((callback) => {
      callback({ ...this.#progress });
    });
  }
}

export const sync = new SyncClient();
