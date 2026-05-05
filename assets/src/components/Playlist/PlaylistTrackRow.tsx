import { TrackRow } from "../../components/Tracks";
import type { TrackItem } from "./types";

interface Props {
  item: TrackItem;
  isSelected: boolean;
  isPlaying?: boolean;
  isDragging?: boolean;
}

export function PlaylistTrackRow({
  item,
  isSelected,
  isPlaying = false,
  isDragging = false,
}: Props) {
  return (
    <TrackRow
      track={item.track}
      number={item.number}
      isSelected={isSelected}
      isPlaying={isPlaying}
      isDragging={isDragging}
      isLastTrack={item.lastTrack === true}
      showTrackArtist={true}
      showAlbumArtwork={true}
    />
  );
}
