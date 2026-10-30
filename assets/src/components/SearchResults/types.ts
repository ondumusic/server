import type { Track } from "../../types";
import type { ListItem as DefaultListItem } from "../SelectableList";

export type TrackItem = DefaultListItem & {
  track: Track;
  isLast: boolean;
};
