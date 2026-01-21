import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useNavigationType, useParams } from "react-router";
import {
  ArtistAlbumListItem,
  type ListItem,
} from "../components/ArtistAlbumListItem";
import { Loading } from "../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import { useArtistQuery } from "../hooks/useArtistQuery";
import { useInfiniteArtistAlbumsQuery } from "../hooks/useInfiniteArtistAlbumsQuery";
import { usePlayer } from "../hooks/usePlayer";
import { useQueue } from "../hooks/useQueue";
import i18next from "../i18next";
import type { Album, Track, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";
import { splitTracksByDisc } from "../utils/splitTracksByDisc";
import { EmptyView } from "../views/EmptyView";

type Params = {
  artistId: UUID;
  albumId?: UUID;
};

function isAlbum(album: Album, albumId?: string): boolean {
  if (!albumId) return false;
  return album.id === albumId || album.slug === albumId;
}

function getTracksById(items: ListItem[], ids: Set<string>): Track[] {
  const selectedTracks: { [key: string]: Track } = items
    .filter((item) => item.type === "track")
    .filter((item) => ids.has(item.id))
    .reduce((acc: { [key: string]: Track }, item) => {
      acc[item.id] = item.track;
      return acc;
    }, {});

  // Return the tracks in the same order as the ids are in the Set
  return [...ids]
    .map((trackId) => selectedTracks[trackId])
    .filter((track) => track);
}

export function ArtistAlbumListView() {
  const navigationType = useNavigationType();
  const { artistId, albumId } = useParams() as Params;
  const { enqueueAndPlay, enqueueNext, enqueueAfter, userConfirmQueueReplace } =
    usePlayer();
  const { currentTrack } = useQueue();
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

  // Reset selection on artist/album change
  // biome-ignore lint/correctness/useExhaustiveDependencies(artistId): dont need it
  // biome-ignore lint/correctness/useExhaustiveDependencies(albumId): dont need it
  useEffect(() => {
    setSelectedTrackIds(new Set());
  }, [artistId, albumId]);

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

  const listItems: ListItem[] = useMemo(() => {
    if (!dataArtist || !data) return [];

    return [
      {
        id: "artistHeader",
        type: "artist",
        selectable: false,
        artist: dataArtist,
      },
      ...paginatedMap<Album, ListItem>(data, (album, albumIndex) => {
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
          ...tracksPerDisc.flatMap((disc): ListItem[] => {
            const trackCount = disc.tracks.length;

            // Convert track to TrackItem
            const tracks = disc.tracks.flatMap(
              (track, trackIndex): ListItem[] => {
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
      }),
    ];
  }, [data, dataArtist]);

  const handlePlayAlbum = useCallback(
    async (item: ListItem) => {
      if (item.type !== "album") return;
      if (!(await userConfirmQueueReplace())) return;

      const albumTracks = paginatedMap<Album, Track>(data, (album) => {
        if (album.id !== item.album.id) return [];
        return album.tracks;
      });

      enqueueAndPlay(albumTracks);
    },
    [data, enqueueAndPlay, userConfirmQueueReplace],
  );

  const onSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;
      const selectedTracks = getTracksById(listItems, selectedIds);
      if (selectedTracks.length === 1) {
        const selectedTrack = selectedTracks[0];

        // The default behaviour we want is to add all tracks from the same
        // album to the queue and start playback at the selected track.
        const albumTracks = paginatedMap<Album, Track>(data, (album) => {
          if (album.id !== selectedTrack.albumId) return [];
          return album.tracks;
        });

        enqueueAndPlay(albumTracks, selectedTrack);
      } else {
        enqueueAndPlay(selectedTracks);
      }
    },
    [listItems, data, enqueueAndPlay, userConfirmQueueReplace],
  );

  const onDoubleClick = useCallback(
    async (item: ListItem) => {
      if (item.type !== "track") return;
      if (!(await userConfirmQueueReplace())) return;

      // The default behaviour we want is to add all tracks from the same
      // album to the queue and start playback at the selected track.
      const albumTracks = paginatedMap<Album, Track>(data, (album) => {
        if (album.id !== item.track.albumId) return [];
        return album.tracks;
      });

      enqueueAndPlay(albumTracks, item.track);
    },
    [data, enqueueAndPlay, userConfirmQueueReplace],
  );

  const onContextMenu = useCallback(
    (selectedIds: Set<string>) => {
      const [firstId] = selectedIds;

      // The context menu for an album works differently.
      const maybeAlbumItem = listItems.find((item) => item.id === firstId);
      if (maybeAlbumItem && maybeAlbumItem.type === "album") {
        const album = maybeAlbumItem.album;

        return [
          {
            key: "play_next",
            label: i18next.t("contextMenu.playNext", {
              defaultValue: "Play Next",
              count: album.tracks.length,
            }),
            onClick() {
              enqueueNext(album.tracks);
            },
          },
          {
            key: "play_after",
            label: i18next.t("contextMenu.playAfter", {
              defaultValue: "Play After",
              count: album.tracks.length,
            }),
            onClick() {
              enqueueAfter(album.tracks);
            },
          },
        ];
      }

      const selectedTracks = getTracksById(listItems, selectedIds);
      if (selectedTracks.length === 0) return [];

      return [
        {
          key: "play_next",
          label: i18next.t("contextMenu.playNext", {
            defaultValue: "Play Next",
            count: selectedTracks.length,
          }),
          onClick() {
            enqueueNext(selectedTracks);
          },
        },
        {
          key: "play_after",
          label: i18next.t("contextMenu.playAfter", {
            defaultValue: "Play After",
            count: selectedTracks.length,
          }),
          onClick() {
            enqueueAfter(selectedTracks);
          },
        },
      ];
    },
    [listItems, enqueueNext, enqueueAfter],
  );

  const renderItem = useCallback(
    (item: ListItem, state: ListItemState) => (
      <ArtistAlbumListItem
        item={item}
        isDragging={state.isDragging}
        isSelected={state.isSelected}
        isPlaying={item.id === currentTrack?.id}
        onPlayAlbum={handlePlayAlbum}
      />
    ),
    [handlePlayAlbum, currentTrack],
  );

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

  const currentAlbum = listItems.find(
    (item) => item.type === "album" && isAlbum(item.album, albumId),
  );

  return (
    <div className="mx-4 lg:mx-8">
      <div className="absolute top-[1px] left-[1px] right-[1px] bg-panel-bg border-b border-accent-500 md:hidden p-4 z-50 font-semibold">
        <Link to="/">
          &larr; All Artists
          {/*TODO: i18n*/}
        </Link>
      </div>
      <SelectableList<ListItem>
        multiple
        allowDrag
        id="albumTracks"
        items={listItems}
        defaultFocusId={currentAlbum?.id}
        defaultFocusType="start"
        selectedIds={selectedTrackIds}
        onChange={setSelectedTrackIds}
        onSubmit={onSubmit}
        onDoubleClick={onDoubleClick}
        onContextMenu={onContextMenu}
        renderItem={renderItem}
      />
    </div>
  );
}
