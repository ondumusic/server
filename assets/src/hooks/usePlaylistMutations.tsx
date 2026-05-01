import { useCallback, useEffect, useState } from "react";
import { type PlaylistOperations, playlistApi } from "../api";
import { sync } from "../library";
import type { PlaylistItem, Track, UUID } from "../types";
import {
  buildAddOperations,
  buildReorderOperations,
  type Item,
  type PendingAdd,
  type PendingState,
} from "../utils/playlistPositions";

const writeItemsToIndexedDb = async (playlistItems?: PlaylistItem[]) => {
  if (!Array.isArray(playlistItems)) return;
  await sync.pushChanges({ playlistItems });
};

const removeItemsFromIndexedDb = async (deletedIds?: UUID[]) => {
  if (!Array.isArray(deletedIds)) return;
  const deletions = deletedIds.map((id) => ({
    entityType: "playlistItem",
    entityId: id,
  }));

  await sync.pushChanges({ deletions });
};

const batchUpdate = (playlistId: UUID, ops: PlaylistOperations) =>
  playlistApi.updatePlaylistItems(playlistId, ops);

const emptyPending: PendingState = {
  moves: new Map(),
  adds: new Map(),
  removes: new Set(),
};

export function usePlaylistMutations(playlistId: string, items: Item[]) {
  const [pending, setPending] = useState<PendingState>(emptyPending);

  // Reconcile pending overlay with committed state.
  // When a committed item reflects a pending change, drop the pending entry.
  useEffect(() => {
    setPending((prev) => {
      const moves = new Map(prev.moves);
      const adds = new Map(prev.adds);
      const removes = new Set(prev.removes);
      let changed = false;

      // A committed item with our staged position confirms the move.
      for (const [itemId, pendingMove] of moves) {
        const committedItem = items.find((i) => i.id === itemId);
        if (committedItem?.position === pendingMove.newPosition) {
          moves.delete(itemId);
          changed = true;
        }
      }

      // A committed item with our staged position confirms the add.
      // Match by position since temp id won't match the real id.
      for (const [tempId, pendingAdd] of adds) {
        if (items.some((i) => i.position === pendingAdd.position)) {
          adds.delete(tempId);
          changed = true;
        }
      }

      // The committed item being absent confirms the remove.
      for (const itemId of removes) {
        if (!items.some((i) => i.id === itemId)) {
          removes.delete(itemId);
          changed = true;
        }
      }

      return changed ? { moves, adds, removes } : prev;
    });
  }, [items]);

  const reorder = useCallback(
    async (selectedIds: Set<string>, insertAtIndex: number) => {
      const result = buildReorderOperations(items, selectedIds, insertAtIndex);
      if (!result) return;

      // Stage optimistic moves.
      setPending((prev) => {
        const moves = new Map(prev.moves);
        for (const m of result.moves) {
          moves.set(m.itemId, { itemId: m.itemId, newPosition: m.position });
        }
        return { ...prev, moves };
      });

      const response = await batchUpdate(playlistId, { move: result.moves });
      await writeItemsToIndexedDb(response.moved);
    },
    [items, playlistId],
  );

  const addTracks = useCallback(
    async (tracks: Track[], insertAtIndex: number) => {
      const trackIds = tracks.map((t) => t.id);
      const result = buildAddOperations(items, trackIds, insertAtIndex);
      if (!result) return;

      const stagedAdds: PendingAdd[] = result.adds.map((a, i) => ({
        playlistId,
        tempId: `tmp-${crypto.randomUUID()}`,
        trackId: a.trackId,
        position: a.position,
        track: tracks[i], // carry full track for optimistic rendering
      }));

      setPending((prev) => {
        const adds = new Map(prev.adds);
        for (const a of stagedAdds) adds.set(a.tempId, a);
        return { ...prev, adds };
      });

      const response = await batchUpdate(playlistId, { add: result.adds });
      await writeItemsToIndexedDb(response.added);
    },
    [items, playlistId],
  );

  const removeItems = useCallback(
    async (itemIds: UUID[]) => {
      if (itemIds.length === 0) return;

      // Separate temp ids (pending adds) from real ids.
      const realIds = itemIds.filter((id) => !id.startsWith("tmp-"));

      // For temp ids, we can't actually cancel the in-flight add request,
      // but we can drop them from the pending overlay.
      // The add will eventually complete and write to IndexedDB; you'd
      // then need a follow-up delete to actually remove them server-side.
      // For v1, just block removes on pending items in the UI.

      if (realIds.length === 0) return;

      setPending((prev) => {
        const removes = new Set(prev.removes);
        const moves = new Map(prev.moves);
        for (const id of realIds) {
          removes.add(id);
          moves.delete(id);
        }
        return { ...prev, moves, removes };
      });

      await batchUpdate(playlistId, { remove: realIds });
      await removeItemsFromIndexedDb(realIds);
    },
    [playlistId],
  );

  return { reorder, addTracks, removeItems, pending };
}
