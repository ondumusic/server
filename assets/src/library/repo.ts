import type { UUID } from "../types";
import {
  applyOp,
  compare,
  opToRange,
  type QueryOperation,
  type RangeOp,
  type SingleValueOp,
} from "./queryHelpers";

type Migrations = {
  [version: number]: (db: IDBDatabase, tx: IDBTransaction | null) => void;
};

type StoreOperations<T> = {
  [storeName: string]: {
    put?: T[];
    del?: UUID[];
  };
};

type QueryCondition<T> = {
  [K in keyof T & string]:
    | [field: K, op: SingleValueOp, value: T[K]]
    | [field: K, op: RangeOp, lower: T[K], upper: T[K]];
}[keyof T & string];

type Query<T> = {
  whereIndex?: QueryCondition<T>;
  having?: {
    [K in keyof T]?:
      | [op: SingleValueOp, value: T[K]]
      | [op: RangeOp, lower: T[K], upper: T[K]]
      | ((value: T[K]) => boolean);
  };
  sortBy?: keyof T & string;
  sortDir?: "asc" | "desc";
};

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

  async get<T>(store: string, key: UUID): Promise<T | undefined> {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");
    return this.#result<T>(tx.objectStore(store).get(key));
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

  async query<T>(
    store: string,
    { whereIndex, having, sortBy, sortDir = "asc" }: Query<T>,
  ): Promise<T[]> {
    const db = await this.instance;
    const tx = db.transaction(store, "readonly");

    let target: IDBObjectStore | IDBIndex = tx.objectStore(store);
    let keyRange = null;
    if (whereIndex) {
      const [indexName, op, ...args] = whereIndex as [
        string,
        QueryOperation,
        ...unknown[],
      ];
      target = target.index(indexName);
      keyRange = opToRange(op, ...args);
    }

    const filters: Array<(r: T) => boolean> = Object.entries(having || {}).map(
      ([field, condition]) => {
        const [op, ...args] = condition as [QueryOperation, ...unknown[]];
        return (r: T) =>
          applyOp((r as Record<string, unknown>)[field], op, ...args);
      },
    );

    // Fast path: sorting by the where field (or no where, sorting by primary key)
    const sortedByIndex =
      sortBy &&
      ((whereIndex && whereIndex[0] === sortBy) ||
        (!whereIndex && sortBy === target.keyPath));

    return new Promise((resolve, reject) => {
      const req = target.getAll(keyRange);
      req.onsuccess = () => {
        let results = req.result;

        if (filters.length) {
          results = results.filter((r) => filters.every((fn) => fn(r)));
        }

        // Already sorted asc by the index by default, so only need to apply
        // our own sort if not by index.
        if (sortBy && !sortedByIndex) {
          results.sort((a, b) => compare(a[sortBy], b[sortBy]));
        }

        if (sortDir === "desc") results.reverse();
        resolve(results);
      };
      req.onerror = () => reject(req.error);
    });
  }

  async getMany<T>(store: string, keys: UUID[]): Promise<T[]> {
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

    this.#instance = undefined;
    return new Promise<void>((resolve, reject) => {
      const req = indexedDB.deleteDatabase(this.#name);
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
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

export const repo = new Repo("musicbox", {
  1: (db) => {
    const tracks = db.createObjectStore("tracks", { keyPath: "id" });
    tracks.createIndex("by_artistId", "artistId", { unique: false });
    tracks.createIndex("by_albumId", "albumId", { unique: false });
    tracks.createIndex("by_albumArtistId", "albumArtistId", { unique: false });

    const artists = db.createObjectStore("artists", { keyPath: "id" });
    artists.createIndex("by_slug", "slug", { unique: true });
    artists.createIndex("filter_albumCount", "albumCount", { unique: false });

    const albums = db.createObjectStore("albums", { keyPath: "id" });
    albums.createIndex("by_slug", "slug", { unique: true });

    // Keeps track of cursor et al.
    db.createObjectStore("meta", { keyPath: "key" });
  },
});
