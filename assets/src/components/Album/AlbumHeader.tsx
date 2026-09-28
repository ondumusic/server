import { Trans } from "react-i18next";
import { formatTotalDuration } from "../../utils/formatTotalDuration";
import { AlbumArtwork } from "../AlbumArtwork";
import type { HeaderItem } from "./types";

export function AlbumHeader({ album, tracks }: HeaderItem) {
  return (
    <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 @md:mb-8 flex items-start gap-6">
      <div className="w-36 flex-shrink-0">
        <AlbumArtwork
          album={album}
          size="large"
          className="w-full shadow-lg aspect-square rounded-sm bg-linear-to-br from-stone-50 to-stone-200"
        />
      </div>

      <div className="pt-4">
        <strong
          className="text-lg font-semibold mb-0.5 block"
          title={album.name}
        >
          {album.name}
        </strong>

        <strong
          className="text-md text-muted font-normal mb-2 block"
          title={album.artistName}
        >
          {album.artistName}
        </strong>
        <div className="flex flex-col @md:flex-row @md:gap-2">
          {album.releaseYear && (
            <span className="text-panel-fg-muted text-sm">
              {album.releaseYear}
            </span>
          )}
          <span className="text-panel-fg-muted text-sm">
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
      </div>
    </header>
  );
}
