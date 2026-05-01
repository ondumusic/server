import { generateNKeysBetween } from "fractional-indexing";
import type { AddOp, MoveOp } from "../api";
import type { PlaylistItem, Track, UUID } from "../types";

export type PendingMove = { itemId: string; newPosition: string };

export type PendingAdd = {
  tempId: string;
  trackId: string;
  playlistId: string;
  position: string;
  track: Track; // full track metadata for rendering
};

export type PendingState = {
  moves: Map<string, PendingMove>; // keyed by itemId
  adds: Map<string, PendingAdd>; // keyed by tempId
  removes: Set<string>; // itemIds
};

export type Item = PlaylistItem & {
  isPending?: boolean;
};

export function findAnchorPositions(
  items: Item[],
  insertAtIndex: number,
  skipIds: Set<UUID> = new Set(),
): { before: string | null; after: string | null } {
  let before: string | null = null;
  for (let i = Math.min(insertAtIndex - 1, items.length - 1); i >= 0; i--) {
    if (!skipIds.has(items[i].id)) {
      before = items[i].position;
      break;
    }
  }

  let after: string | null = null;
  for (let i = Math.max(insertAtIndex, 0); i < items.length; i++) {
    if (!skipIds.has(items[i].id)) {
      after = items[i].position;
      break;
    }
  }

  return { before, after };
}

export function buildReorderOperations(
  items: Item[],
  selectedIds: Set<UUID>,
  insertAtIndex: number,
): { moves: MoveOp[]; originals: MoveOp[] } | null {
  const movedItems = items.filter((item) => selectedIds.has(item.id));
  if (movedItems.length === 0) return null;

  const zeroBased = insertAtIndex - 1;
  const { before, after } = findAnchorPositions(items, zeroBased, selectedIds);
  const newPositions = generateNKeysBetween(before, after, movedItems.length);

  const moves = movedItems.map((item, i) => ({
    itemId: item.id,
    position: newPositions[i],
  }));

  const originals = movedItems.map((item) => ({
    itemId: item.id,
    position: item.position,
  }));

  return { moves, originals };
}

export function buildAddOperations(
  items: Item[],
  trackIds: UUID[],
  insertAtIndex: number,
): { adds: AddOp[] } | null {
  if (trackIds.length === 0) return null;

  const { before, after } = findAnchorPositions(items, insertAtIndex);
  const newPositions = generateNKeysBetween(before, after, trackIds.length);

  const adds = trackIds.map((trackId, i) => ({
    trackId: trackId,
    position: newPositions[i],
  }));

  return { adds };
}

export function applyPending(committed: Item[], pending: PendingState): Item[] {
  const result: Item[] = [];
  const committedPositions = new Set(committed.map((i) => i.position));

  for (const item of committed) {
    if (pending.removes.has(item.id)) continue;

    const stagedMove = pending.moves.get(item.id);
    if (stagedMove) {
      result.push({ ...item, position: stagedMove.newPosition });
    } else {
      result.push(item);
    }
  }

  for (const add of pending.adds.values()) {
    if (committedPositions.has(add.position)) continue; // committed has caught up
    result.push({
      __type: "playlistItem",
      id: add.tempId,
      playlistId: add.playlistId,
      trackId: add.trackId,
      track: add.track,
      position: add.position,
      insertedAt: new Date().toISOString(),
      isPending: true,
    });
  }

  return result.sort((a, b) => (a.position < b.position ? -1 : 1));
}
