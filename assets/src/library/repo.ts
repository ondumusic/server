type Migrations = {
  [version: number]: (db: IDBDatabase, tx: IDBTransaction | null) => void;
};

import type { UUID } from "../types";

class Repo {
  #name: string;
  #migrations: Migrations;
  #version: number;
  #instance?: Promise<IDBDatabase>;

  constructor(name: string, migrations: Migrations) {
    this.#name = name;
    this.#migrations = migrations;
    this.#version =
      Object.keys(migrations)
        .map((v) => parseInt(v, 10))
        .sort()
        .at(-1) || 1;
  }

  get instance() {
    if (!this.#instance) {
      this.#instance = new Promise((resolve, reject) => {
        const db = indexedDB.open(this.#name, this.#version);
        db.onupgradeneeded = (e) => {
          const d = db.result;
          const tx = db.transaction;
          for (let v = e.oldVersion + 1; v <= this.#version; v++) {
            this.#migrations[v]?.(d, tx);
          }
        };
        db.onsuccess = () => resolve(db.result);
        db.onerror = () => reject(db.error);
      });
    }

    return this.#instance;
  }

  async getOne<T>(store: string, key: UUID) {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    return this.#result<T>(tx.objectStore(store).get(key));
  }

  async getAll<T>(store: string, indexName?: string, query?: IDBKeyRange) {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    const target = indexName
      ? tx.objectStore(store).index(indexName)
      : tx.objectStore(store);

    return this.#result<T[]>(target.getAll(query));
  }

  async getMany<T>(store: string, keys: UUID[]) {
    if (!keys.length) return [];

    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    const target = tx.objectStore(store);
    const results = [];

    for (const key of keys) {
      const result = await this.#result<T>(target.get(key));
      if (result) results.push(result);
    }

    return results;
  }

  async count(store: string) {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    return this.#result<number>(tx.objectStore(store).count());
  }

  #result<T>(req: IDBRequest<T>) {
    return new Promise((resolve, reject) => {
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }
}

export const repo = new Repo("musicbox", {
  1: (db) => {
    const tracks = db.createObjectStore("tracks", { keyPath: "id" });
    tracks.createIndex("by_artistId", "artistId", { unique: false });
    tracks.createIndex("by_albumId", "albumId", { unique: false });
    tracks.createIndex("by_albumArtistId", "albumArtistId", { unique: false });

    const artists = db.createObjectStore("artists", { keyPath: "id" });
    artists.createIndex("by_slug", "slug", { unique: true });

    const albums = db.createObjectStore("albums", { keyPath: "id" });
    albums.createIndex("by_slug", "slug", { unique: true });

    // Keeps track of cursor et al.
    db.createObjectStore("meta", { keyPath: "key" });
  },
});
