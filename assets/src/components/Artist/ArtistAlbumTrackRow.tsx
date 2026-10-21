import { TrackRow } from "../../components/Tracks";
import type { TrackItem } from "./types";

interface Props {
  item: TrackItem;
  isSelected: boolean;
  isPlaying?: boolean;
  isDragging?: boolean;
}

export function ArtistAlbumTrackRow({
  item,
  isSelected,
  isPlaying = false,
  isDragging = false,
}: Props) {
  return (
    <div className="@2xl:pl-34 @3xl:pl-50">
      <TrackRow
        track={item.track}
        number={item.track.number}
        isSelected={isSelected}
        isPlaying={isPlaying}
        isDragging={isDragging}
        isLastTrack={item.lastTrackOnDisc}
        showTrackArtist={item.showTrackArtist}
        showAlbumArtwork={false}
      />
    </div>
  );
}
