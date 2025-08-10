import { Trans } from "react-i18next";
import type { AlbumArtist } from "../types";

interface Props {
  albumArtist: AlbumArtist;
}

export function ArtistAlbumListHeader({ albumArtist }: Props) {
  return (
    <header className="pb-4 border-b border-stone-300">
      <h1 className="font-semibold text-2xl">{albumArtist.name}</h1>
      <span className="text-sm text-stone-400">
        <Trans i18nKey="artistAlbumCount" count={albumArtist.albumCount}>
          {{ count: albumArtist.albumCount }} albums
        </Trans>
      </span>
    </header>
  );
}
