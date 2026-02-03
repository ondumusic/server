import { queryClient } from "../api";
import type { Track, UUID } from "../types";
import { client, type RequestOptions } from "./client";

export const trackQueries = {
  getTrack(trackId?: UUID, opts?: RequestOptions) {
    return {
      enabled: !!trackId,
      queryKey: ["track", trackId],
      queryFn: ({ signal }: { signal?: AbortSignal }) =>
        client.get<undefined, Track>(`/tracks/${trackId}`, { ...opts, signal }),
    };
  },
};

export const trackApi = {
  getTrack(trackId: UUID, opts?: RequestOptions) {
    return queryClient.ensureQueryData<Track>(
      trackQueries.getTrack(trackId, opts),
    );
  },
};
