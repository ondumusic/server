import type { Artist, UUID } from "../types";
import type { ArtworkResult } from "./artwork";
import { client, type RequestOptions } from "./client";

export const artistApi = {
  getArtist(artistId: UUID, opts?: RequestOptions) {
    return client.get<undefined, Artist>(`/artists/${artistId}`, opts);
  },

  paginateArtists(opts?: RequestOptions) {
    return client.get<undefined, Artist>("/artists", opts);
  },

  putArtwork(artistId: UUID, file: File, opts?: RequestOptions) {
    const body = new FormData();
    body.append("file", file);

    return client.put<FormData, ArtworkResult<Artist>>(
      `/artists/${artistId}/artwork`,
      body,
      opts,
    );
  },

  deleteArtwork(artistId: UUID, opts?: RequestOptions) {
    return client.delete<undefined, ArtworkResult<Artist>>(
      `/artists/${artistId}/artwork`,
      opts,
    );
  },
};
