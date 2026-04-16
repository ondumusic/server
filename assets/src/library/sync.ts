import { client } from "../api";
import type { Album, Artist, Track } from "../types";
import { notifyChanges } from "./events";
import { repo } from "./repo";
import { transforms } from "./transforms";

interface SyncMeta {
  key: string;
  value: string;
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

class SyncClient {
  #syncing: boolean = false;

  async startSync() {
    if (this.#syncing) {
      throw new Error("failed to start sync, syncing already in progress");
    }

    this.#syncing = true;
    const cursor = await this.#getCursor();

    try {
      await this.#fetch(cursor);
    } finally {
      this.#syncing = false;
    }
  }

  async #fetch(cursor?: string) {
    const result = await client.get<undefined, SyncResponse>(`/sync`, {
      search: cursor ? { cursor } : {},
    });

    // Process upserts
    await repo.putMany<Artist>(
      "artists",
      await transforms.artists(result.artists),
    );
    await repo.putMany<Album>("albums", await transforms.albums(result.albums));
    await repo.putMany<Track>("tracks", await transforms.tracks(result.tracks));

    // Process deletions
    const deletions = Map.groupBy(result.deletions ?? [], (e) => e.entityType);
    await repo.deleteMany(
      "artists",
      deletions.get("artist")?.map((d) => d.entityId) ?? [],
    );
    await repo.deleteMany(
      "albums",
      deletions.get("album")?.map((d) => d.entityId) ?? [],
    );
    await repo.deleteMany(
      "tracks",
      deletions.get("track")?.map((d) => d.entityId) ?? [],
    );

    // Check which stores changed and notify events
    const changedStores = new Set<string>();
    if (result.artists.length) changedStores.add("artists");
    if (result.albums.length) changedStores.add("albums");
    if (result.tracks.length) changedStores.add("tracks");
    if (deletions.get("artist")?.length) changedStores.add("artists");
    if (deletions.get("album")?.length) changedStores.add("albums");
    if (deletions.get("track")?.length) changedStores.add("tracks");
    if (changedStores.size > 0) notifyChanges([...changedStores]);

    // Fetch next page unless completed.
    if (result.complete) {
      this.#setCursor(result.cursor);
    } else {
      this.#fetch(result.cursor);
    }
  }

  async #getCursor() {
    const meta = await repo.get<SyncMeta>("meta", "sync-cursor");
    return meta?.value;
  }

  async #setCursor(cursor: string) {
    await repo.put("meta", { key: "sync-cursor", value: cursor });
  }
}

export const sync = new SyncClient();
