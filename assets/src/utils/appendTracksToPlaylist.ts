import { generateNKeysBetween } from "fractional-indexing";
import { type PlaylistOperations, playlistApi } from "../api";
import { queryPlaylistsItems, sync } from "../library";
import type { PlaylistItem, Track, UUID } from "../types";

const batchUpdate = (playlistId: UUID, ops: PlaylistOperations) =>
  playlistApi.updatePlaylistItems(playlistId, ops);

const writeItemsToIndexedDb = async (playlistItems?: PlaylistItem[]) => {
  if (!Array.isArray(playlistItems)) return;
  await sync.pushChanges({ playlistItems });
};

async function getLastPlaylistItemPosition(playlistId: UUID) {
  const items = await queryPlaylistsItems(playlistId);
  if (!items.length) return null;
  return (items.pop() as PlaylistItem).position;
}

export async function appendTracksToPlaylist(
  playlistId: UUID,
  tracks: Track[],
) {
  if (tracks.length === 0) return [];
  const lastPosition = await getLastPlaylistItemPosition(playlistId);
  const newPositions = generateNKeysBetween(lastPosition, null, tracks.length);

  const apiAdds = tracks.map((track, i) => ({
    trackId: track.id,
    position: newPositions[i],
  }));

  const response = await batchUpdate(playlistId, { add: apiAdds });
  await writeItemsToIndexedDb(response.added);
  return response.added;
}
