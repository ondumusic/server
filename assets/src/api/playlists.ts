import type { UUID } from "../types";
import { client, type RequestOptions } from "./client";

interface DeletePlaylistResponse {
  ok: boolean;
}

export const playlistApi = {
  deletePlaylist(playlistId: UUID, opts?: RequestOptions) {
    return client.delete<undefined, DeletePlaylistResponse>(
      `/playlists/${playlistId}`,
      opts,
    );
  },
};
