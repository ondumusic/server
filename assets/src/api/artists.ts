import type { Artist, UUID } from "../types";
import { client, type RequestOptions } from "./client";

export const artistApi = {
  getArtist(artistId: UUID, opts?: RequestOptions) {
    return client.get<undefined, Artist>(`/artists/${artistId}`, opts);
  },

  paginateArtists(opts?: RequestOptions) {
    return client.get<undefined, Artist>("/artists", opts);
  },
};
