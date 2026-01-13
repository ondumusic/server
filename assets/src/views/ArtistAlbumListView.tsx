import { useEffect, useMemo, useState } from "react";
import { useNavigationType, useParams } from "react-router";
import { ArtistAlbumListHeader } from "../components/ArtistAlbumListHeader";
import { Loading } from "../components/Loading";
import {
  type Item as ListItem,
  SelectableList,
} from "../components/SelectableList";
import { useArtistQuery } from "../hooks/useArtistQuery";
import { useInfiniteArtistAlbumsQuery } from "../hooks/useInfiniteArtistAlbumsQuery";
import { usePlayer } from "../hooks/usePlayer";
import i18next from "../i18next";
import type { Album, Disc, Track, UUID } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";
import { formatTotalDuration } from "../utils/formatTotalDuration";
import { paginatedMap } from "../utils/paginatedMap";
import { splitTracksByDisc } from "../utils/splitTracksByDisc";
import { EmptyView } from "../views/EmptyView";

type Params = {
  artistId: UUID;
  albumId?: UUID;
};

type AlbumItem = ListItem & {
  type: "album";
  album: Album;
  firstAlbumInList: boolean;
};

type DiscItem = ListItem & {
  type: "disc";
  disc: Disc;
};

type TrackItem = ListItem & {
  type: "track";
  track: Track;
  albumTrackCount: number;
  showTrackArtist: boolean;
  firstTrackOnDisc: boolean;
  lastTrackOnDisc: boolean;
};

type CustomListItem = AlbumItem | DiscItem | TrackItem;

function isAlbum(album: Album, albumId?: string): boolean {
  if (!albumId) return false;
  return album.id === albumId || album.slug === albumId;
}

export function ArtistAlbumListView() {
  const navigationType = useNavigationType();
  const { artistId, albumId } = useParams() as Params;
  const { enqueueAndPlay, enqueueNext, enqueueAfter } = usePlayer();
  const hasArtistId = !!artistId;
  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set(),
  );
  const [useSuspense, setUseSuspense] = useState(
    hasArtistId && navigationType === "POP",
  );

  useEffect(() => {
    if (useSuspense) setUseSuspense(false);
  });

  const suspendUntil = albumId
    ? (entry: Album) => isAlbum(entry, albumId)
    : undefined;

  const {
    isFetching: isFetchingArtist,
    data: dataArtist,
    error: errorArtist,
  } = useArtistQuery(
    { artistId },
    {
      enabled: hasArtistId,
      suspense: useSuspense,
    },
  );

  const { isFetching, hasFirstPage, data, error } =
    useInfiniteArtistAlbumsQuery(
      {
        artistId: dataArtist?.id,
      },
      {
        enabled: !!dataArtist?.id,
        suspense: useSuspense,
        suspendUntil,
      },
    );

  const listItems = useMemo(() => {
    return paginatedMap<Album, CustomListItem>(data, (album, albumIndex) => {
      const tracksPerDisc = splitTracksByDisc(album.tracks);

      // Only show disc number headers if there is more than one.
      const showDiscNumbers = tracksPerDisc.length > 1;

      // Only show track artists if there is more than one.
      const showTrackArtist =
        new Set(album.tracks.map((track) => track.artist.id)).size > 1;

      // Return album item and iterate over tracks
      return [
        {
          id: album.id,
          type: "album",
          selectable: false,
          album,
          firstAlbumInList: albumIndex === 0,
        },
        ...tracksPerDisc.flatMap((disc): CustomListItem[] => {
          const trackCount = disc.tracks.length;

          // Convert track to TrackItem
          const tracks = disc.tracks.flatMap(
            (track, trackIndex): CustomListItem[] => {
              return [
                {
                  id: track.id,
                  type: "track",
                  track,
                  showTrackArtist,
                  albumTrackCount: album.tracks.length,
                  firstTrackOnDisc: trackIndex === 0,
                  lastTrackOnDisc: trackIndex === trackCount - 1,
                },
              ];
            },
          );

          // Conditionally include disc headers
          if (showDiscNumbers) {
            return [
              {
                id: `${album.id}-disc-${disc.number}`,
                type: "disc",
                selectable: false,
                disc,
              },
              ...tracks,
            ];
          } else {
            return tracks;
          }
        }),
      ];
    });
  }, [data]);

  if (!artistId)
    return (
      <EmptyView
        message={i18next.t("emptyView.noResults", {
          defaultValue: "No Results",
        })}
      />
    );

  if ((isFetching || isFetchingArtist) && !hasFirstPage) return <Loading />;
  if (errorArtist) throw errorArtist;
  if (error) throw error;
  if (!dataArtist) return;

  return (
    <div className="space-y-8 mx-4 lg:mx-8 my-4 lg:my-8">
      <ArtistAlbumListHeader artist={dataArtist} />

      <SelectableList<CustomListItem>
        items={listItems}
        selectedIds={selectedTrackIds}
        onChange={setSelectedTrackIds}
        onSubmit={(selectedIds) => {
          const albumTracks: Track[] = listItems
            .filter((item) => item.type === "track")
            .filter((item) => selectedIds.has(item.id))
            .map((item) => item.track);

          enqueueAndPlay(albumTracks);
        }}
        onDoubleClick={(item) => {
          if (item.type !== "track") return;

          const albumTracks = paginatedMap<Album, Track>(data, (album) => {
            if (album.id !== item.track.albumId) return [];
            return album.tracks;
          });

          enqueueAndPlay(albumTracks, item.track);
        }}
        onContextMenu={(selectedIds) => {
          const albumTracks: Track[] = listItems
            .filter((item) => item.type === "track")
            .filter((item) => selectedIds.has(item.id))
            .map((item) => item.track);

          return [
            {
              key: "play_next",
              label: i18next.t("contextMenu.playNext", {
                defaultValue: "Play Next",
                count: albumTracks.length,
              }),
              onClick() {
                enqueueNext(albumTracks);
              },
            },
            {
              key: "play_after",
              label: i18next.t("contextMenu.playAfter", {
                defaultValue: "Play After",
                count: albumTracks.length,
              }),
              onClick() {
                enqueueAfter(albumTracks);
              },
            },
          ];
        }}
        renderItem={(item, state) => {
          switch (item.type) {
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
                <div className="pl-52">
                  <div
                    className={classNames([
                      "flex w-full gap-2 text-sm py-1.5 px-2",
                      state.isSelected && "bg-blue-500 text-white",
                      state.isSelected && "rounded-t-md rounded-b-md",
                      state.isSelected &&
                        "[[aria-selected=true]+[aria-selected=true]_&]:rounded-t-none",
                      state.isSelected &&
                        "[[aria-selected=true]:has(+[aria-selected=true])_&]:rounded-b-none",
                      item.lastTrackOnDisc &&
                        item.albumTrackCount > 3 &&
                        "mb-6",
                      item.lastTrackOnDisc &&
                        item.albumTrackCount <= 3 &&
                        "mb-19",
                    ])}
                  >
                    <span
                      className={classNames([
                        "w-6 flex-shrink-0 font-light text-right",
                        !state.isSelected && "text-stone-400",
                      ])}
                    >
                      {item.track.number}.
                    </span>
                    <div>
                      {item.track.name}

                      {item.showTrackArtist && (
                        <span
                          className={classNames([
                            "block",
                            !state.isSelected && "text-stone-400",
                          ])}
                        >
                          {item.track.artist.name}
                        </span>
                      )}
                    </div>
                    <span
                      className={classNames([
                        "ml-auto font-light",
                        !state.isSelected && "text-stone-400",
                      ])}
                    >
                      {formatDuration(item.track.duration)}
                    </span>
                  </div>
                </div>
              );
          }
        }}
      />
    </div>
  );
}
