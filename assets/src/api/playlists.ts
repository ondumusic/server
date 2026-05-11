import type { Playlist, PlaylistItem, UUID } from "../types";
import { client, type RequestOptions } from "./client";

interface CreatePlaylistRequest {
  name: string;
  parentId?: UUID;
  isFolder?: boolean;
}

interface UpdatePlaylistRequest {
  name?: string;
  parentId?: UUID | null;
}

interface DeletePlaylistResponse {
  ok: boolean;
}

export type AddOp = {
  position: string;
  trackId: UUID;
};

export type MoveOp = {
  position: string;
  itemId: UUID;
};

export type RemoveOp = UUID;

export interface PlaylistOperations {
  add?: AddOp[];
  move?: MoveOp[];
  remove?: UUID[];
}

interface UpdatePlaylistItemsResponse {
  ok: boolean;
  added?: PlaylistItem[];
  moved?: PlaylistItem[];
  removed?: RemoveOp[];
}

export const playlistApi = {
  createPlaylist(params: CreatePlaylistRequest, opts?: RequestOptions) {
    return client.post<CreatePlaylistRequest, Playlist>(
      "/playlists",
      params,
      opts,
    );
  },

  updatePlaylist(
    playlistId: UUID,
    params: UpdatePlaylistRequest,
    opts?: RequestOptions,
  ) {
    return client.patch<UpdatePlaylistRequest, Playlist>(
      `/playlists/${playlistId}`,
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

  updatePlaylistItems(
    playlistId: UUID,
    ops: PlaylistOperations,
    opts?: RequestOptions,
  ) {
    return client.patch<PlaylistOperations, UpdatePlaylistItemsResponse>(
      `/playlists/${playlistId}/items`,
      ops,
      opts,
    );
  },
};
