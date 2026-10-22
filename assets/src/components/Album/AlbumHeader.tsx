import { Trans } from "react-i18next";
import { formatTotalDuration } from "../../utils/formatTotalDuration";
import { AlbumArtwork } from "../AlbumArtwork";
import { PlayShuffleButtons } from "../PlayShuffleButtons";
import type { HeaderItem } from "./types";

export function AlbumHeader({ album, tracks }: HeaderItem) {
  return (
    <header className="mt-4 lg:mt-5 @md:pb-4 @md:mb-2 flex items-start gap-6">
      <div className="w-28 mt-1.5 flex-shrink-0">
        <AlbumArtwork
          album={album}
          size="large"
          className="w-full shadow-lg aspect-square rounded-md bg-linear-to-br from-stone-50 to-stone-200"
        />
      </div>

      <div className="min-w-0">
        <h1 className="font-semibold text-2xl line-clamp-1" title={album.name}>
          {album.name}
        </h1>

        <strong
          className="text-md text-muted font-normal mb-2 block"
          title={album.artistName}
        >
          {album.artistName}
        </strong>
        <div className="flex flex-col @md:flex-row @md:gap-2">
          {album.releaseYear && (
            <span className="text-page-fg-muted text-sm @md:after:content-['·'] @md:after:ml-2">
              {album.releaseYear}
            </span>
          )}
          <span className="text-page-fg-muted text-sm">
            <Trans
              i18nKey="album.trackCount"
              count={tracks.length}
              duration={formatTotalDuration(tracks)}
            >
              {{ count: tracks.length }} tracks,{" "}
              {{ duration: formatTotalDuration(tracks) }}
            </Trans>
          </span>
        </div>

        <PlayShuffleButtons input={{ albumId: album.id }} className="mt-3" />
      </div>
    </header>
  );
}
