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

    this.#prewarmArtwork(albums);
  }

  async #fetch(cursor?: string) {
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

  async #getCursor() {
    const meta = await repo.get<SyncMeta>("meta", "sync-cursor");
    return meta?.value;
  }

  async #setCursor(cursor: string) {
    return await repo.put("meta", { key: "sync-cursor", value: cursor });
  }
}

export const sync = new SyncClient();
