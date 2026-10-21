import { Trans } from "react-i18next";
import { PlayShuffleButtons } from "../PlayShuffleButtons";
import type { ArtistItem } from "./types";

interface Props {
  item: ArtistItem;
}

export function ArtistHeaderRow({ item }: Props) {
  return (
    <header className="mt-18 md:mt-4 lg:mt-5 @md:pb-4 flex items-end justify-between gap-4">
      <div className="min-w-0">
        <h1
          className="font-semibold text-4xl lg:text-2xl line-clamp-1"
          title={item.artist.name}
        >
          {item.artist.name}
        </h1>
        <span className="text-sm text-panel-fg-muted">
          <Trans i18nKey="artist.albumCount" count={item.artist.albumCount}>
            {{ count: item.artist.albumCount }} albums
          </Trans>
        </span>
      </div>

      <PlayShuffleButtons
        input={{ artistId: item.artist.id }}
        className="flex-shrink-0"
      />
    </header>
  );
}
