import { useMemo, useState } from "react";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { TrackRow } from "../../components/Tracks";
import type { Album as TAlbum, Track } from "../../types";
import { AlbumHeader } from "./AlbumHeader";
import type { ListItem } from "./types";

export function Album({ album, tracks }: { album: TAlbum; tracks: Track[] }) {
  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set(),
  );

  const listItems = useMemo(() => {
    const items: ListItem[] = tracks.map((track) => ({
      type: "track",
      id: track.id,
      track,
    }));

    if (album) {
      items.unshift({
        type: "header",
        id: "header",
        selectable: false,
        album,
        tracks,
      });
    }

    return items;
  }, [tracks, album]);

  const renderItem = (item: ListItem, state: ListItemState) => {
    if (item.type === "header") {
      return <AlbumHeader {...item} />;
    }

    if (item.type === "track") {
      return (
        <TrackRow
          track={item.track}
          number={item.track.number}
          isSelected={state.isSelected}
          isPlaying={false}
          isDragging={state.isDragging}
          isLastTrack={false}
          showTrackArtist={false}
          showAlbumArtwork={false}
        />
      );
    }
  };

  return (
    <SelectableList<ListItem>
      multiple
      allowDrag
      allowDropFrom={[]}
      id="albumTracks"
      items={listItems}
      renderItem={renderItem}
      selectedIds={selectedTrackIds}
      onChange={setSelectedTrackIds}
      paddingBottom={32}
    />
  );
}
