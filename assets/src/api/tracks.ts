import type { Track, UUID } from "../types";
import { client, type RequestOptions } from "./client";

interface Params {
  artistId?: UUID;
  albumId?: UUID;
  sortBy?: "random" | "default";
}

export const trackApi = {
  getTrack(trackId: UUID, opts?: RequestOptions) {
    return client.get<undefined, Track>(`/tracks/${trackId}`, opts);
  },

  paginateTracks(params: Params, opts?: RequestOptions) {
    const search = opts?.search ?? {};
    if (params.artistId) search.artist_id = params.artistId;
    if (params.albumId) search.album_id = params.albumId;
    if (params.sortBy === "random") {
      search.sort_by = "random";
      search.random_seed = Math.round(
        100000 + Math.random() * 1000000 * Date.now(),
      ).toString();
    }

    return client.paginate<undefined, Track>(`/tracks`, {
      ...opts,
      search: {
        ...search,
      },
    });
  },
};
