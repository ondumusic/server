import { useCallback, useEffect, useRef, useState } from "react";
import { subscribe } from "./events";
import { type Repo, repo } from "./repo";

export function useStoreQuery<T>(
  store: string,
  queryFn: (repo: Repo) => Promise<T[]>,
  // deps: unknown[] = []
) {
  const [data, setData] = useState<T[]>([]);
  const [error, setError] = useState<unknown>(null);
  const queryRef = useRef(queryFn);

  const load = useCallback(async () => {
    if (!queryRef.current) return;

    try {
      const results = await queryRef.current(repo);
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
  // const depKey = JSON.stringify(deps);
  useEffect(() => {
    load();
  }, [load]);
  // }, [depKey, load]);

  return {
    data,
    error,
    loading: data === undefined && error === null,
  };
}

export function useStoreRecord<T>(
  store: string,
  queryFn: (repo: Repo) => Promise<T | undefined>,
  // deps: unknown[] = []
) {
  const [data, setData] = useState<T | undefined>(undefined);
  const [error, setError] = useState<unknown>(null);
  const queryRef = useRef(queryFn);

  const load = useCallback(async () => {
    if (!queryRef.current) return;

    try {
      const results = await queryRef.current(repo);
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
  // const depKey = JSON.stringify(deps);
  useEffect(() => {
    load();
  }, [load]);
  // }, [depKey, load]);

  return {
    data,
    error,
    loading: data === undefined && error === null,
  };
}
