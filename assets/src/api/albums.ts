import type { Album, UUID } from "../types";
import { client, type RequestOptions } from "./client";

export const albumApi = {
  getAlbum(albumId: UUID, opts?: RequestOptions) {
    return client.get<undefined, Album>(`/albums/${albumId}`, opts);
  },

  paginateAlbums(artistId: UUID, opts?: RequestOptions) {
    return client.paginate<undefined, Album>(
      `/artists/${artistId}/albums`,
      opts,
    );
  },
};
