import { useCallback } from "react";
import { Trans, useTranslation } from "react-i18next";
import { PlayIcon } from "../../components/icons/PlayIcon";
import { classNames } from "../../utils/classNames";
import { formatTotalDuration } from "../../utils/formatTotalDuration";
import { AlbumArtwork } from "../AlbumArtwork";

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
    <div
      className={classNames([
        "relative flex gap-4 mb-4 z-20",
        !item.firstAlbumInList && "mt-12",
        // The header has no divider, so the first album can sit closer to it
        item.firstAlbumInList && "mt-4",
      ])}
    >
      <div className="relative @2xl:absolute top-0 left-0 w-20 flex-grow-0 flex-shrink-0 @2xl:w-30 @3xl:w-46 group/artwork">
        <AlbumArtwork
          album={item.album}
          size="large"
          className="w-full shadow-lg aspect-square rounded-md bg-linear-to-br from-stone-50 to-stone-200"
        />

        <button
          type="button"
          onDoubleClick={handlePlayAlbum}
          className="absolute left-0 top-0 w-full h-full opacity-0 group-hover/artwork:opacity-100 transition-opacity"
        >
          <div className="m-auto flex justify-center align-center size-8 @2xl:size-12 @3xl:size-16 bg-accent-500 rounded-full shadow-lg transition-colors">
            <PlayIcon
              className="size-4 @2xl:size-6 @3xl:size-8 m-auto text-white"
              title={t("button.playSelectedAlbum", {
                defaultValue: "Play {{ albumName }}",
                albumName: item.album.name,
              })}
            />
          </div>
        </button>
      </div>

      <div className="pt-1 @2xl:pl-46 @3xl:pl-62 w-full">
        <div className="pb-2 mb-2 min-h-20 @2xl:min-h-auto @2xl:border-b border-page-fg-divider">
          <strong
            className="text-lg font-semibold mb-0.5 line-clamp-1"
            title={item.album.name}
          >
            {item.album.name}
          </strong>
          <div className="flex flex-col @2xl:flex-row @2xl:gap-2">
            {item.album.releaseYear && (
              <span className="text-page-fg-muted text-sm @2xl:after:content-['·'] @2xl:after:ml-2">
                {item.album.releaseYear}
              </span>
            )}
            <span className="text-page-fg-muted text-sm">
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
