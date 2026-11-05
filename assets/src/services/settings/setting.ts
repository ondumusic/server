export type Definition =
  | { type: "string"; defaultValue: string | null; oneOf?: readonly string[] }
  | { type: "boolean"; defaultValue: boolean | null };

export type SettingValue<D extends Definition> =
  | NonNullable<Extract<Definition, { type: D["type"] }>["defaultValue"]>
  | Extract<D["defaultValue"], null>;

type Listener = () => void;

export class Setting<T> {
  readonly key: string;
  #storage: Storage;
  #definition: Definition;
  #listeners = new Set<Listener>();

  constructor(key: string, storage: Storage, definition: Definition) {
    this.key = key;
    this.#storage = storage;
    this.#definition = definition;
  }

  get = (): T => {
    const raw = this.#storage.getItem(this.key);
    const { type, defaultValue } = this.#definition;
    if (raw === null) return defaultValue as T;
    return (type === "boolean" ? raw === "true" : raw) as T;
  };

  set = (value: T) => {
    if (value === null) {
      this.#storage.removeItem(this.key);
    } else {
      this.#storage.setItem(this.key, String(value));
    }
    this.notify();
  };

  reset() {
    this.#storage.removeItem(this.key);
    this.notify();
  }

  subscribe = (listener: Listener): (() => void) => {
    this.#listeners.add(listener);
    return () => this.#listeners.delete(listener);
  };

  notify() {
    for (const listener of this.#listeners) listener();
  }
}
