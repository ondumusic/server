import { useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { authQueries, queryClient } from "../api";

interface Params {
  enabled: boolean;
}

export function usePlayTokenQuery({ enabled }: Params) {
  const queryFn = enabled ? useSuspenseQuery : useQuery;
  const query = authQueries.getPlayToken();

  const { data, isStale } = queryFn({
    ...query,
    staleTime: 1800 * 1000,
    enabled,
  });

  if (isStale || (enabled && !data?.ok)) {
    queryClient.invalidateQueries({ queryKey: query.queryKey });
  }

  if (data?.ok && data.playToken) return { playToken: data.playToken, isStale };
  return { playToken: undefined, isStale };
}
