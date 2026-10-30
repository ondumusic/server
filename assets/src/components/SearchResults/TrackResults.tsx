import { useCallback, useEffect, useMemo, useState } from "react";
import { usePlayer } from "../../hooks/usePlayer";
import { useQueue } from "../../hooks/useQueue";
import type { Track } from "../../types";
import { type ListItemState, SelectableList } from "../SelectableList";
import { TrackRow } from "../Tracks";
import type { TrackItem } from "./types";

interface Props {
  tracks: Track[];
}

export function TrackResults({ tracks }: Props) {
  const { enqueueAndPlay, userConfirmQueueReplace } = usePlayer();
  const { currentTrack } = useQueue();
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  // Clears the selection when the results change.
  // biome-ignore lint/correctness/useExhaustiveDependencies(tracks): only used to trigger a reset
  useEffect(() => {
    setSelectedIds(new Set());
  }, [tracks]);

  // Build the list items
  const listItems = useMemo(() => {
    const lastIndex = tracks.length - 1;
    const items: TrackItem[] = [];

    for (const [index, track] of tracks.entries()) {
      const isLast = index === lastIndex;

      items.push({
        id: track.id,
        track,
        isLast,
      });
    }

    return items;
  }, [tracks]);

  const handleDoubleClick = useCallback(
    async (item: TrackItem) => {
      if (!(await userConfirmQueueReplace())) return;
      enqueueAndPlay([{ track: item.track }]);
    },
    [enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleSubmit = useCallback(
    async (ids: Set<string>) => {
      const selected = tracks.filter((track) => ids.has(track.id));
      if (!selected.length) return;
      if (!(await userConfirmQueueReplace())) return;
      enqueueAndPlay(selected.map((track) => ({ track })));
    },
    [tracks, enqueueAndPlay, userConfirmQueueReplace],
  );

  const renderItem = useCallback(
    (item: TrackItem, state: ListItemState) => (
      <TrackRow
        track={item.track}
        number={0}
        isSelected={state.isSelected}
        isPlaying={item.id === currentTrack?.id}
        isDragging={state.isDragging}
        isLastTrack={item.isLast}
        showNumber={false}
      />
    ),
    [currentTrack],
  );

  return (
    <SelectableList<TrackItem>
      id="searchTracks"
      multiple
      allowDrag
      allowDropFrom={[]}
      items={listItems}
      renderItem={renderItem}
      selectedIds={selectedIds}
      onChange={setSelectedIds}
      onSubmit={handleSubmit}
      onDoubleClick={handleDoubleClick}
    />
  );
}
