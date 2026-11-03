import { Trans } from "react-i18next";
import { artworkUrl } from "../../utils/artwork";
import { ArtistArtwork } from "../ArtistArtwork";
import { PlayShuffleButtons } from "../PlayShuffleButtons";
import type { ArtistItem } from "./types";

interface Props {
  item: ArtistItem;
}

export function ArtistHeaderRow({ item }: Props) {
  const { artist } = item;

  if (artworkUrl(artist)) {
    return (
      <header className="mt-4 lg:mt-5 @md:pb-8 flex items-center gap-6">
        <div className="w-36 flex-shrink-0">
          <ArtistArtwork
            artist={artist}
            size="large"
            className="w-full aspect-square rounded-full"
          />
        </div>

        <div className="min-w-0">
          <h1
            className="font-semibold text-4xl lg:text-2xl line-clamp-1"
            title={artist.name}
          >
            {artist.name}
          </h1>
          <span className="text-sm text-page-fg-muted">
            <Trans i18nKey="artist.albumCount" count={artist.albumCount}>
              {{ count: artist.albumCount }} albums
            </Trans>
          </span>

          <PlayShuffleButtons
            input={{ artistId: artist.id }}
            className="mt-3"
          />
        </div>
      </header>
    );
  }

  return (
    <header className="mt-4 lg:mt-5 @md:pb-4 flex items-end justify-between gap-4">
      <div className="min-w-0">
        <h1
          className="font-semibold text-4xl lg:text-2xl line-clamp-1"
          title={artist.name}
        >
          {artist.name}
        </h1>
        <span className="text-sm text-page-fg-muted">
          <Trans i18nKey="artist.albumCount" count={artist.albumCount}>
            {{ count: artist.albumCount }} albums
          </Trans>
        </span>
      </div>

      <PlayShuffleButtons
        input={{ artistId: artist.id }}
        className="flex-shrink-0"
      />
    </header>
  );
}
