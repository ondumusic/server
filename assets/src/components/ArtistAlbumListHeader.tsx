import { Trans } from "react-i18next";
import type { Artist } from "../types";

interface Props {
  artist: Artist;
}

export function ArtistAlbumListHeader({ artist }: Props) {
  return (
    <header className="pb-4 border-b border-stone-300">
      <h1 className="font-semibold text-4xl lg:text-2xl">{artist.name}</h1>
      <span className="text-sm text-stone-400">
        <Trans i18nKey="artist.albumCount" count={artist.albumCount}>
          {{ count: artist.albumCount }} albums
        </Trans>
      </span>
    </header>
  );
}
