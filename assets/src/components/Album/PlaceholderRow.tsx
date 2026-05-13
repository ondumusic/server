import type { PlaceholderItem } from "./types";

interface Props {
  item: PlaceholderItem;
}

export function PlaceholderRow(_props: Props) {
  // Placeholder fills up space so the overflowing/floating album artwork
  // will still have enough space beneath it.
  return <div className="h-12" />;
}
