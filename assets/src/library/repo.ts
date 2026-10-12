import type { UUID } from "../types";
import { executeJoins } from "./repo/joinHelpers";
import {
  applyOp,
  collectStores,
  opToRange,
  type Query,
  type QueryOperation,
  type RangeQuery,
  usesIdRange,
} from "./repo/queryHelpers";
import { executeSort } from "./repo/sortHelpers";

type Migrations = {
  [version: number]: (db: IDBDatabase, tx: IDBTransaction | null) => void;
};

type StoreOperations<T> = {
  [storeName: string]: {
    put?: T[];
    del?: UUID[];
  };
};

export class Repo {
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

  async get<T>(store: string, key: UUID): Promise<T | undefined> {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    return this.#result<T>(tx.objectStore(store).get(key));
  }

  async getBy<T>(
    store: string,
    indexName: string,
    value: IDBValidKey,
  ): Promise<T | undefined> {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    return this.#result<T>(tx.objectStore(store).index(indexName).get(value));
  }

  async getAll<T>(
    store: string,
    indexName?: string,
    query?: IDBKeyRange,
  ): Promise<T[]> {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    const target = indexName
      ? tx.objectStore(store).index(indexName)
      : tx.objectStore(store);

    return this.#result<T[]>(target.getAll(query));
  }

  async query<T extends { id: UUID }>(
    store: string,
    query: Query<T>,
    transaction?: IDBTransaction,
  ): Promise<T[]> {
    const db = await this.instance;

    // Get all stores in this query (so including from joins etc.)
    const stores = collectStores(store, query);

    // If we are already inside a transaction we can use that instead of
    // creating a new one.
    const tx = transaction ?? db.transaction(stores, "readonly");
    const objectStore = tx.objectStore(store);
    const keyPath = objectStore.keyPath;

    // For a simple "id" in [...] we can just run getMany.
    if (
      usesIdRange(query as Omit<Query<T>, "join">, keyPath as string | string[])
    ) {
      const keys = (query.whereIndex as [string, "in", UUID[]])[2];
      const rows = await this.getMany<T>(store, keys, tx);
      if (!query.join) return rows;
      return executeJoins(this, rows, query.join, tx);
    }

    // It's not simple, let's figure out how to get our data.
    let target: IDBObjectStore | IDBIndex = objectStore;
    let rangeQuery: RangeQuery = { kind: "range", range: null };

    // whereIndex can do a simple index based lookup, neat!
    if (query.whereIndex) {
      const [indexName, op, ...args] = query.whereIndex as [
        string,
        QueryOperation,
        ...unknown[],
      ];
      if (objectStore.keyPath !== indexName) {
        target = objectStore.index(indexName);
      }
      rangeQuery = opToRange(op, ...args);
    }

    // Convert `having` filters to in-memory filters
    const filters: Array<(r: T) => boolean> = Object.entries(
      query.having || {},
    ).map(([field, condition]) => {
      if (typeof condition === "function") {
        return (r: T) => condition((r as Record<string, unknown>)[field]);
      }
      const [op, ...args] = condition as [QueryOperation, ...unknown[]];
      return (r: T) =>
        applyOp((r as Record<string, unknown>)[field], op, ...args);
    });

    // Fetch function that actually gets the data from IndexedDB
    const fetchResults = (): Promise<T[]> => {
      if (rangeQuery.kind === "in") {
        // For "in" range requests with 0 keys we don't need to do much.
        if (rangeQuery.keys.length === 0) return Promise.resolve([]);

        // For "in" range queries that don't use the primary key we will do
        // a getAll using IDBKeyRange and then flatten results.
        return Promise.all(
          rangeQuery.keys.map((key) =>
            this.#result<T[]>(target.getAll(IDBKeyRange.only(key))),
          ),
        ).then((chunks) => chunks.flat());
      }

      // If it's not an "in" range query we will get everything,
      // ideally it is still using an index but not guaranteed.
      return this.#result<T[]>(target.getAll(rangeQuery.range));
    };

    let results = await fetchResults();

    // If we have any "having" filters we apply them now.
    if (filters.length) {
      results = results.filter((r) => filters.every((fn) => fn(r)));
    }

    // If we have custom sorting rules we apply them now.
    if (query.sortBy) {
      executeSort(results, query.sortBy, query.sortDir ?? "asc");
    }

    // If there are no joins we're done
    if (!query.join) return results;

    // Otherwise it's time to execute the joins on these results.
    return executeJoins(this, results, query.join, tx);
  }

  async getMany<T>(
    store: string,
    keys: UUID[],
    transaction?: IDBTransaction,
  ): Promise<T[]> {
    if (!keys.length) return [];

    const db = await this.instance;
    const tx = transaction ?? db.transaction(store, "readonly");
    const target = tx.objectStore(store);

    // Fire all requests synchronously, then await all at once
    const requests = keys.map((key) => this.#result<T>(target.get(key)));
    return Promise.all(requests).then((results) => results.filter((r) => !!r));
  }

  async count(store: string) {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    return this.#result<number>(tx.objectStore(store).count());
  }

  async put<T>(store: string, item: T) {
    return this.putMany(store, [item]);
  }

  async putMany<T>(store: string, items: T[]) {
    if (!items.length) return;
    return await this.#write({ [store]: { put: items } });
  }

  async delete(store: string, key: UUID) {
    return this.deleteMany(store, [key]);
  }

  async deleteMany(store: string, keys: UUID[]) {
    if (!keys.length) return;
    return await this.#write({ [store]: { del: keys } });
  }

  async truncate(store: string) {
    return this.truncateMany([store]);
  }

  async truncateMany(stores: string[]) {
    const db = await this.instance;
    const tx = db.transaction(stores, "readwrite");

    return new Promise<void>((resolve, reject) => {
      for (const store of stores) tx.objectStore(store).clear();
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  }

  async teardown() {
    const db = await this.instance;
    if (!db) return;
    db.close();

    this.#instance = undefined;
    return new Promise<void>((resolve, reject) => {
      const req = indexedDB.deleteDatabase(this.#name);
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
      req.onblocked = () => {
        console.warn(
          "Failed to delete indexedDB, blocked by other connection.",
        );
      };
    });
  }

  #result<T>(req: IDBRequest<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async #write<T>(operations: StoreOperations<T>) {
    const storeNames = Object.keys(operations);
    if (!storeNames.length) return;
    const db = await this.instance;

    return new Promise<void>((resolve, reject) => {
      const tx = db.transaction(storeNames, "readwrite");
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);

      Object.entries(operations).forEach(
        ([storeName, { put = [], del = [] }]) => {
          const store = tx.objectStore(storeName);
          for (const item of put) store.put(item);
          for (const key of del) store.delete(key);
        },
      );
    });
  }
}

export const repo = new Repo("ondu", {
  1: (db) => {
    const tracks = db.createObjectStore("tracks", { keyPath: "id" });
    tracks.createIndex("by_missingData", "missingData", { unique: false });
    tracks.createIndex("by_artistId", "artistId", { unique: false });
    tracks.createIndex("by_albumId", "albumId", { unique: false });
    tracks.createIndex("by_albumArtistId", "albumArtistId", { unique: false });
    tracks.createIndex("by_albumReleaseYear", "albumReleaseYear", {
      unique: false,
    });

    const artists = db.createObjectStore("artists", { keyPath: "id" });
    artists.createIndex("by_missingData", "missingData", { unique: false });
    artists.createIndex("by_slug", "slug", { unique: true });
    artists.createIndex("filter_albumCount", "albumCount", { unique: false });

    const albums = db.createObjectStore("albums", { keyPath: "id" });
    albums.createIndex("by_missingData", "missingData", { unique: false });
    albums.createIndex("by_artistId", "artistId", { unique: false });
    albums.createIndex("by_slug", "slug", { unique: false }); // slugs are only unique artist_slug+album_slug

    const playlists = db.createObjectStore("playlists", { keyPath: "id" });
    playlists.createIndex("by_missingData", "missingData", { unique: false });
    playlists.createIndex("by_hasParent", "hasParent", { unique: false });
    playlists.createIndex("by_parentId", "parentId", { unique: false });

    const playlistItems = db.createObjectStore("playlistItems", {
      keyPath: "id",
    });
    playlistItems.createIndex("by_missingData", "missingData", {
      unique: false,
    });
    playlistItems.createIndex("by_playlistId", "playlistId", { unique: false });

    // Keeps track of cursor et al.
    db.createObjectStore("meta", { keyPath: "key" });
  },
});
