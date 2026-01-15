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

type TrackItem = DefaultListItem & {
  type: "track";
  track: Track;
  albumTrackCount: number;
  showTrackArtist: boolean;
  firstTrackOnDisc: boolean;
  lastTrackOnDisc: boolean;
};

export type ListItem = ArtistItem | AlbumItem | DiscItem | TrackItem;

interface Props {
  item: ListItem;
  isSelected: boolean;
}

export function ArtistAlbumListItem({ item, isSelected }: Props) {
  const { t } = useTranslation();

  switch (item.type) {
    case "artist":
      return (
        <header className="mt-4 lg:mt-8 pb-4 mb-8 border-b border-stone-300">
          <h1 className="font-semibold text-4xl lg:text-2xl">
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
        <div
          className={classNames([
            "relative flex gap-4 mb-4",
            !item.firstAlbumInList && "mt-12",
          ])}
        >
          <div className="absolute top-0 left-0 w-48 shadow-lg aspect-square rounded-sm overflow-hidden bg-stone-200">
            {item.album.artworkUrl && (
              <img
                src={item.album.artworkUrl}
                alt=""
                className="w-full object-cover object-center"
              />
            )}
          </div>

          <div className="pt-1 pl-62 w-full">
            <div className="pb-2 mb-2 border-b border-stone-200">
              <strong className="text-lg font-semibold mb-0.5">
                {item.album.name}
              </strong>
              <div className="flex gap-2">
                <span className="text-stone-400 text-sm">
                  {item.album.releaseYear}
                </span>
                <span className="text-stone-400 text-sm">
                  {formatTotalDuration(item.album.tracks)}
                </span>
                <span className="text-stone-400 text-sm">
                  {item.album.tracks.length} tracks
                </span>
              </div>
            </div>
          </div>
        </div>
      );

    case "disc":
      return (
        <div className="font-semibold text-xs text-gray-500 pl-62">
          Disc {item.disc.number}
        </div>
      );

    case "track":
      return (
        <div className="pl-52 group/track">
          <div
            className={classNames([
              "flex w-full gap-2 text-sm py-1.5 px-2",
              isSelected && "bg-blue-500 text-white",
              isSelected && "rounded-t-md rounded-b-md",
              isSelected &&
                "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
              isSelected &&
                "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
              item.lastTrackOnDisc && item.albumTrackCount > 3 && "mb-6",
              item.lastTrackOnDisc && item.albumTrackCount <= 3 && "mb-19",
            ])}
          >
            <span
              className={classNames([
                "w-6 flex-shrink-0 font-light text-right",
                "group-hover/track:hidden",
                !isSelected && "text-stone-400",
              ])}
            >
              {item.track.number && `${item.track.number}.`}
            </span>

            <div className="w-6 hidden group-hover/track:flex justify-end pt-1 flex-shrink-0">
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
              {item.track.name}

              {item.showTrackArtist && (
                <span
                  className={classNames([
                    "block",
                    !isSelected && "text-stone-400",
                  ])}
                >
                  {item.track.artist.name}
                </span>
              )}
            </div>
            <span
              className={classNames([
                "ml-auto font-light",
                !isSelected && "text-stone-400",
              ])}
            >
              {formatDuration(item.track.duration)}
            </span>
          </div>
        </div>
      );
  }
}
