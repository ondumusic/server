import { useSuspenseQuery } from "@tanstack/react-query";
import { api } from "../services/api";
import { queryClient } from "../utils/queryClient";

type Request = undefined;
interface Response {
  ok: boolean;
  playToken?: string;
}

export function usePlayTokenQuery() {
  const { data, isStale } = useSuspenseQuery({
    queryKey: ["playToken"],
    queryFn: () => api.get<Request, Response>(`/auth/playtoken`),
    staleTime: 1800 * 1000,
  });

  if (isStale) {
    queryClient.invalidateQueries({ queryKey: ["playToken"] });
  }

  if (data.ok && data.playToken) return { playToken: data.playToken, isStale };
  return { playToken: undefined, isStale };
}
