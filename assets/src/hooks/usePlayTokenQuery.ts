import { useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { client } from "../api";
import { queryClient } from "../api/queryClient";

interface Params {
  enabled: boolean;
}

type Request = undefined;
interface Response {
  ok: boolean;
  playToken?: string;
}

const getPlayToken = async () => {
  try {
    return await client.get<Request, Response>(`/auth/playtoken`);
  } catch (_e) {
    return { ok: false };
  }
};

export function usePlayTokenQuery({ enabled }: Params) {
  const queryFn = enabled ? useSuspenseQuery : useQuery;

  const { data, isStale } = queryFn({
    queryKey: ["playToken"],
    queryFn: () => getPlayToken(),
    staleTime: 1800 * 1000,
    enabled,
  });

  if (isStale || (enabled && !data?.ok)) {
    queryClient.invalidateQueries({ queryKey: ["playToken"] });
  }

  if (data?.ok && data.playToken) return { playToken: data.playToken, isStale };
  return { playToken: undefined, isStale };
}
