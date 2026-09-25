import { useCallback } from "react";
import { Trans, useTranslation } from "react-i18next";
import { PlayIcon } from "../../components/icons/PlayIcon";
import { artworkUrl } from "../../utils/artwork";
import { formatTotalDuration } from "../../utils/formatTotalDuration";

import type { AlbumItem } from "./types";

interface Props {
  item: AlbumItem;
  onPlayAlbum?: (item: AlbumItem) => void;
}

export function ArtistAlbumRow({ item, onPlayAlbum }: Props) {
  const { t } = useTranslation();

  const handlePlayAlbum = useCallback(
    () => onPlayAlbum?.(item),
    [item, onPlayAlbum],
  );

  return (
    <div className="relative flex gap-4 mb-4 z-20 mt-12">
      <div className="relative @md:absolute top-0 left-0 w-20 flex-grow-0 flex-shrink-0 @md:w-32 @xl:w-48 group/artwork">
        <div className="w-full shadow-lg aspect-square rounded-sm overflow-hidden bg-linear-to-br from-stone-50 to-stone-200">
          {artworkUrl(item.album) && (
            <img
              src={artworkUrl(item.album)}
              alt=""
              className="w-full aspect-square object-cover object-center"
            />
          )}
        </div>

        <button
          type="button"
          onDoubleClick={handlePlayAlbum}
          className="absolute left-0 top-0 w-full h-full opacity-0 group-hover/artwork:opacity-100 transition-opacity"
        >
          <div className="m-auto flex justify-center align-center w-8 h-8 md:w-16 md:h-16 bg-accent-500 rounded-full shadow-lg transition-colors">
            <PlayIcon
              className="size-4 md:size-8 m-auto text-white"
              title={t("button.playSelectedAlbum", {
                defaultValue: "Play {{ albumName }}",
                albumName: item.album.name,
              })}
            />
          </div>
        </button>
      </div>

      <div className="pt-1 @md:pl-46 @xl:pl-62 w-full">
        <div className="pb-2 mb-2 min-h-20 @md:min-h-auto @md:border-b border-panel-fg-divider">
          <strong
            className="text-lg font-semibold mb-0.5 line-clamp-1"
            title={item.album.name}
          >
            {item.album.name}
          </strong>
          <div className="flex flex-col @md:flex-row @md:gap-2">
            {item.album.releaseYear && (
              <span className="text-panel-fg-muted text-sm">
                {item.album.releaseYear}
              </span>
            )}
            <span className="text-panel-fg-muted text-sm">
              <Trans
                i18nKey="album.trackCount"
                count={item.album.tracks.length}
                duration={formatTotalDuration(item.album.tracks)}
              >
                {{ count: item.album.tracks.length }} tracks,{" "}
                {{ duration: formatTotalDuration(item.album.tracks) }}
              </Trans>
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
