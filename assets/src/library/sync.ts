import { client } from "../api";
import type { Album, Artist, Track } from "../types";
import { repo } from "./repo";

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
    // TODO: Add transformations
    await repo.putMany<Artist>("artists", result.artists ?? []);
    await repo.putMany<Album>("albums", result.albums ?? []);
    await repo.putMany<Track>("tracks", result.tracks ?? []);

    // Process deletions
    const deletions = result.deletions ?? [];
    await repo.deleteMany(
      "artists",
      deletions.filter((d) => d.entityType === "artist").map((d) => d.entityId),
    );
    await repo.deleteMany(
      "albums",
      deletions.filter((d) => d.entityType === "album").map((d) => d.entityId),
    );
    await repo.deleteMany(
      "tracks",
      deletions.filter((d) => d.entityType === "track").map((d) => d.entityId),
    );

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
