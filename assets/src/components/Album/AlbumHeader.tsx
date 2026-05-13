import { Trans } from "react-i18next";
import { formatTotalDuration } from "../../utils/formatTotalDuration";
import type { HeaderItem } from "./types";

export function AlbumHeader({ album, tracks }: HeaderItem) {
  return (
    <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 @md:mb-8 flex items-start gap-6">
      <div className="max-w-36 flex-shrink-0">
        <div className="w-full shadow-lg aspect-square rounded-sm overflow-hidden bg-linear-to-br from-stone-50 to-stone-200">
          {album.artworkUrl && (
            <img
              src={album.artworkUrl}
              alt=""
              className="w-full aspect-square object-cover object-center"
            />
          )}
        </div>
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
