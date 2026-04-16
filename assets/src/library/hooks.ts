import { useCallback, useEffect, useRef, useState } from "react";
import { subscribe } from "./events";
import { type Repo, repo } from "./repo";

export function useStoreQuery<T>(
  store: string,
  queryFn: (repo: Repo) => Promise<T[]>,
  // deps: unknown[] = []
) {
  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
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
    } finally {
      setLoading(false);
    }
  }, []);

  // Subscribe to change events
  useEffect(() => {
    return subscribe(store, load);
  }, [store, load]);

  // Re-query when deps change (e.g. filters)
  // const depKey = JSON.stringify(deps);
  useEffect(() => {
    setLoading(true);
    load();
  }, [load]);
  // }, [depKey, load]);

  return { data, loading, error };
}
