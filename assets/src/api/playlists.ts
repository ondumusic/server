import type { Playlist, UUID } from "../types";
import { client, type RequestOptions } from "./client";

interface CreatePlaylistRequest {
  name: string;
  parentId?: UUID;
  isFolder?: boolean;
}

interface DeletePlaylistResponse {
  ok: boolean;
}

export const playlistApi = {
  createPlaylist(params: CreatePlaylistRequest, opts?: RequestOptions) {
    return client.post<CreatePlaylistRequest, Playlist>(
      "/playlists",
      params,
      opts,
    );
  },

  deletePlaylist(playlistId: UUID, opts?: RequestOptions) {
    return client.delete<undefined, DeletePlaylistResponse>(
      `/playlists/${playlistId}`,
      opts,
    );
  },
};
