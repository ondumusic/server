import { memo, useCallback } from "react";
import { Trans, useTranslation } from "react-i18next";
import { PlayIcon } from "../components/icons/PlayIcon";
import type { ListItem as DefaultListItem } from "../components/SelectableList";
import type { Album, Artist, Disc, Track } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";
import { formatTotalDuration } from "../utils/formatTotalDuration";

type ArtistItem = DefaultListItem & {
  type: "artist";
  artist: Artist;
};

type AlbumItem = DefaultListItem & {
  type: "album";
  album: Album;
  firstAlbumInList: boolean;
};

type DiscItem = DefaultListItem & {
  type: "disc";
  disc: Disc;
};

type PlaceholderItem = DefaultListItem & {
  type: "placeholder";
};

type TrackItem = DefaultListItem & {
  type: "track";
  track: Track;
  showTrackArtist: boolean;
  lastTrackOnDisc: boolean;
};

export type ListItem =
  | ArtistItem
  | AlbumItem
  | DiscItem
  | TrackItem
  | PlaceholderItem;

interface Props {
  item: ListItem;
  isSelected: boolean;
  isPlaying?: boolean;
  isDragging?: boolean;
  onPlayAlbum?: (item: ListItem) => void;
}

export const ArtistAlbumListItem = memo(
  ({ item, isSelected, isPlaying, isDragging, onPlayAlbum }: Props) => {
    const { t } = useTranslation();

    const handlePlayAlbum = useCallback(
      () => onPlayAlbum?.(item),
      [item, onPlayAlbum],
    );

    switch (item.type) {
      case "artist":
        return (
          <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 @md:border-b border-stone-300">
            <h1
              className="font-semibold text-4xl lg:text-2xl line-clamp-1"
              title={item.artist.name}
            >
              {item.artist.name}
            </h1>
            <span className="text-sm text-stone-400">
              <Trans i18nKey="artist.albumCount" count={item.artist.albumCount}>
                {{ count: item.artist.albumCount }} albums
              </Trans>
            </span>
          </header>
        );

      case "album":
        return (
          <div className="relative flex gap-4 mb-4 z-20 mt-12">
            <div className="relative @md:absolute top-0 left-0 w-20 flex-grow-0 flex-shrink-0 @md:w-32 @xl:w-48 group/artwork">
              <div className="w-full shadow-lg aspect-square rounded-sm overflow-hidden bg-linear-to-br from-stone-50 to-stone-200">
                {item.album.artworkUrl && (
                  <img
                    src={item.album.artworkUrl}
                    alt=""
                    className="w-full object-cover object-center"
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

            <div className="pt-1 @md:pl-44 @xl:pl-60 w-full">
              <div className="pb-2 mb-2 min-h-20 @md:min-h-auto @md:border-b border-stone-200">
                <strong
                  className="text-lg font-semibold mb-0.5 line-clamp-1"
                  title={item.album.name}
                >
                  {item.album.name}
                </strong>
                <div className="flex flex-col @md:flex-row @md:gap-2">
                  {item.album.releaseYear && (
                    <span className="text-stone-400 text-sm">
                      {item.album.releaseYear}
                    </span>
                  )}
                  <span className="text-stone-400 text-sm">
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

      case "disc":
        return (
          <div className="font-semibold text-xs text-gray-500 pl-6 @md:pl-44 @xl:pl-60">
            <Trans i18nKey="album.discNumber" disc={item.disc.number}>
              Disc {{ disc: item.disc.number }}
            </Trans>
          </div>
        );

      case "placeholder":
        // Placeholder fills up space so the overflowing/floating album artwork
        // will still have enough space beneath it.
        return <div className="h-12" />;

      case "track":
        return (
          <div className="@md:pl-34 @xl:pl-50 group/track">
            <div
              className={classNames([
                "flex w-full items-center h-12 gap-2 text-sm py-1.5 @md:px-2",
                isDragging && "opacity-50",
                isSelected &&
                  "bg-blue-400 [.selectable-list:focus_&]:bg-blue-500 text-white",
                isSelected && "rounded-t-md rounded-b-md",
                isSelected &&
                  "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
                isSelected &&
                  "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
                "border-b",
                item.lastTrackOnDisc ? "border-transparent" : "border-gray-200",
              ])}
            >
              <span
                className={classNames([
                  "w-4 @md:w-6 flex-shrink-0 font-light text-right tabular-nums",
                  "group-hover/track:hidden",
                  !isSelected && "text-stone-400",
                  isPlaying && "hidden",
                ])}
              >
                {item.track.number && `${item.track.number}.`}
              </span>

              <div
                className={classNames([
                  "w-4 @md:w-6 group-hover/track:flex justify-end pt-1 flex-shrink-0",
                  !isPlaying ? "hidden" : "flex",
                ])}
              >
                <PlayIcon
                  className={classNames([
                    "size-3 text-accent-500",
                    isSelected && "text-white",
                  ])}
                  title={t("button.playSelectedTrack", {
                    defaultValue: "Play {{ trackName }}",
                    trackName: item.track.name,
                  })}
                />
              </div>

              <div>
                <div
                  className={classNames([
                    "w-full",
                    item.showTrackArtist ? "line-clamp-1" : "line-clamp-2",
                  ])}
                  title={item.track.name}
                >
                  {item.track.name}
                </div>

                {item.showTrackArtist && (
                  <div
                    className={classNames([
                      "w-full line-clamp-1",
                      !isSelected && "text-stone-400",
                    ])}
                    title={item.track.artist.name}
                  >
                    {item.track.artist.name}
                  </div>
                )}
              </div>

              <span
                className={classNames([
                  "ml-auto font-light flex-shrink-0 tabular-nums",
                  !isSelected && "text-stone-400",
                ])}
              >
                {formatDuration(item.track.duration)}
              </span>
            </div>
          </div>
        );
    }
  },
);
