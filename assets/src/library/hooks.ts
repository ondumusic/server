import { useCallback, useEffect, useRef, useState } from "react";
import { subscribe } from "./events";

interface Options {
  enabled?: boolean;
}

export function useStoreQuery<T>(
  store: string,
  queryFn: () => Promise<T[]>,
  deps: unknown[] = [],
  opts: Options = {},
) {
  const [data, setData] = useState<T[] | undefined>(undefined);
  const [error, setError] = useState<unknown>(null);
  const enabledRef = useRef(opts.enabled !== false);
  enabledRef.current = opts.enabled !== false;
  const queryRef = useRef(queryFn);
  queryRef.current = queryFn;

  const load = useCallback(async () => {
    if (!enabledRef.current) return;
    if (!queryRef.current) return;

    try {
      const results = await queryRef.current();
      setData(results);
      setError(null);
    } catch (err) {
      console.error("Query failed:", err);
      setError(err);
    }
  }, []);

  // Subscribe to change events
  useEffect(() => {
    return subscribe(store, load);
  }, [store, load]);

  // Re-query when deps change (e.g. filters)
  const depKey = JSON.stringify(deps);

  // biome-ignore lint/correctness/useExhaustiveDependencies(depKey): dont need it
  useEffect(() => {
    load();
  }, [depKey, load]);

  return {
    data: data ?? [],
    error,
    loading: data === undefined && error === null,
  };
}

export function useStoreRecord<T>(
  store: string,
  queryFn: () => Promise<T | undefined>,
  deps: unknown[] = [],
  opts: Options = {},
) {
  const [data, setData] = useState<T | null | undefined>(undefined);
  const [error, setError] = useState<unknown>(null);
  const queryRef = useRef(queryFn);
  queryRef.current = queryFn;
  const enabledRef = useRef(opts.enabled !== false);
  enabledRef.current = opts.enabled !== false;

  const load = useCallback(async () => {
    if (!enabledRef.current) return;
    if (!queryRef.current) return;

    try {
      const results = await queryRef.current();
      setData(results ?? null);
      setError(null);
    } catch (err) {
      console.error("Query failed:", err);
      setError(err);
    }
  }, []);

  // Subscribe to change events
  useEffect(() => {
    return subscribe(store, load);
  }, [store, load]);

  // Re-query when deps change (e.g. filters)
  const depKey = JSON.stringify(deps);

  // biome-ignore lint/correctness/useExhaustiveDependencies(depKey): dont need it
  useEffect(() => {
    load();
  }, [depKey, load]);

  return {
    data,
    error,
    loading: data === undefined && error === null,
  };
}
