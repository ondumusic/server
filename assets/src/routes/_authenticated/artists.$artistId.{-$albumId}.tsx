import {
  createFileRoute,
  Link,
  Navigate,
  notFound,
  useRouter,
} from "@tanstack/react-router";
import { useCallback, useEffect, useMemo, useState } from "react";

import {
  ArtistAlbumListItem,
  type ListItem,
} from "../../components/ArtistAlbumListItem";
import { EmptyView } from "../../components/EmptyView";
import { Loading } from "../../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistPicker } from "../../hooks/usePlaylistPicker";
import { useQueue } from "../../hooks/useQueue";
import i18next from "../../i18next";
import { queryArtist, useArtistAlbums } from "../../library";
import type { Album, Track, UUID } from "../../types";
import { appendTracksToPlaylist } from "../../utils/appendTracksToPlaylist";
import { splitTracksByDisc } from "../../utils/splitTracksByDisc";

export const Route = createFileRoute(
  "/_authenticated/artists/$artistId/{-$albumId}",
)({
  async loader({ params: { artistId } }: { params: { artistId?: UUID } }) {
    if (!artistId) return;
    const artist = await queryArtist(artistId);
    if (!artist) throw notFound();
    return artist;
  },
  staticData: { view: "artists" as const },
  component: Artists,
  notFoundComponent: () => <Navigate to="/artists" />,
});

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

function Artists() {
  const { artistId, albumId } = Route.useParams() as Params;
  const router = useRouter();
  const { showPlaylistPicker, getMostRecentPlaylist } = usePlaylistPicker();
  const isPopNavigation = router.history.location.state?.isBackForward;
  const {
    enqueueAndPlay,
    enqueueNext,
    enqueueAfter,
    populateUpNext,
    userConfirmQueueReplace,
  } = usePlayer();

  // const { data: dataArtist } = useArtist(artistId);
  const dataArtist = Route.useLoaderData();
  const { currentTrack } = useQueue();
  const hasArtistId = !!artistId;
  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set(),
  );
  const [useSuspense, setUseSuspense] = useState(
    hasArtistId && isPopNavigation,
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

  const { data, error, loading: isFetching } = useArtistAlbums(dataArtist?.id);

  const listItems: ListItem[] = useMemo(() => {
    if (!dataArtist || !data) return [];

    return [
      {
        id: "artistHeader",
        type: "artist" as const,
        selectable: false,
        artist: dataArtist,
      },
      ...data.flatMap((album, albumIndex) => {
        const tracksPerDisc = splitTracksByDisc(album.tracks);

        // Only show disc number headers if there is more than one.
        const showDiscNumbers = tracksPerDisc.length > 1;

        // Only show track artists if there is more than one.
        const showTrackArtist =
          new Set(album.tracks.map((track) => track.artistId)).size > 1;

        // Return album item and iterate over tracks
        return [
          {
            id: album.id,
            type: "album" as const,
            selectable: false,
            album,
            firstAlbumInList: albumIndex === 0,
          },
          ...tracksPerDisc.flatMap((disc, discIndex): ListItem[] => {
            const trackCount = disc.tracks.length;

            // Convert track to TrackItem
            const tracks = disc.tracks.flatMap(
              (track, trackIndex): ListItem[] => {
                return [
                  {
                    id: track.id,
                    type: "track" as const,
                    track,
                    showTrackArtist,
                    lastTrackOnDisc: trackIndex === trackCount - 1,
                  },
                ];
              },
            );

            // Add placeholders if there aren't enough tracks to fill up
            // the visual space.
            const placeholderCount = Math.max(0, 3 - album.tracks.length);
            for (let i = 0; i < placeholderCount; i++) {
              tracks.push({
                id: `${album.id}-placeholder-track-${i}`,
                selectable: false,
                type: "placeholder" as const,
              });
            }

            if (showDiscNumbers) {
              tracks.unshift({
                id: `${album.id}-disc-${disc.number}`,
                type: "disc" as const,
                selectable: false,
                disc,
              });

              // Add whitespace between previous disc and this disc
              if (discIndex !== 0) {
                tracks.unshift({
                  id: `${album.id}-placeholder-disc-${disc.number}`,
                  selectable: false,
                  type: "placeholder" as const,
                });
              }
            }

            return tracks;
          }),
        ];
      }),
    ];
  }, [data, dataArtist]);

  const handlePlayAlbum = useCallback(
    async (item: ListItem) => {
      if (item.type !== "album") return;
      if (!(await userConfirmQueueReplace())) return;

      const albumTracks = data.flatMap((album) => {
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
        const albumTracks = data.flatMap((album) => {
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
      const albumTracks = data.flatMap((album) => {
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
      const recentPlaylist = getMostRecentPlaylist();

      // The context menu for an album works differently.
      const maybeAlbumItem = listItems.find((item) => item.id === firstId);
      if (maybeAlbumItem && maybeAlbumItem.type === "album") {
        const album = maybeAlbumItem.album;

        const albumPlaylistActions = [
          {
            type: "item",
            key: "add_to_playlist",
            label: i18next.t("contextMenu.addToPlaylist", {
              defaultValue: "Add To Playlist...",
              count: album.tracks.length,
            }),
            onClick: async () => {
              const playlistId = await showPlaylistPicker();
              if (!playlistId) return;
              await appendTracksToPlaylist(playlistId as UUID, album.tracks);
            },
          },
        ];

        if (recentPlaylist) {
          albumPlaylistActions.unshift({
            type: "item",
            key: "add_to_recent_playlist",
            label: i18next.t("contextMenu.addToRecentPlaylist", {
              defaultValue: "Add To {{ playlistName }}",
              playlistName: recentPlaylist.name,
            }),
            onClick: async () => {
              await appendTracksToPlaylist(
                recentPlaylist.id as UUID,
                album.tracks,
              );
            },
          });
        }

        return [
          {
            type: "item",
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
            type: "item",
            key: "play_after",
            label: i18next.t("contextMenu.playAfter", {
              defaultValue: "Add To Queue",
              count: album.tracks.length,
            }),
            onClick() {
              enqueueAfter(album.tracks);
            },
          },
          {
            type: "item",
            key: "shuffle_album",
            label: i18next.t("contextMenu.shuffleAlbum", {
              defaultValue: "Shuffle Album",
              count: album.tracks.length,
            }),
            async onClick() {
              if (!(await userConfirmQueueReplace())) return;
              populateUpNext({ albumId: album.id, random: true });
            },
          },
          {
            type: "divider" as const,
            key: "playlist_actions",
          },
          ...albumPlaylistActions,
        ];
      }

      const selectedTracks = getTracksById(listItems, selectedIds);
      if (selectedTracks.length === 0) return [];

      const playlistActions = [
        {
          type: "item",
          key: "add_to_playlist",
          label: i18next.t("contextMenu.addToPlaylist", {
            defaultValue: "Add To Playlist...",
            count: selectedTracks.length,
          }),
          onClick: async () => {
            const playlistId = await showPlaylistPicker();
            if (!playlistId) return;
            await appendTracksToPlaylist(playlistId as UUID, selectedTracks);
          },
        },
      ];

      if (recentPlaylist) {
        playlistActions.unshift({
          type: "item",
          key: "add_to_recent_playlist",
          label: i18next.t("contextMenu.addToRecentPlaylist", {
            defaultValue: "Add To {{ playlistName }}",
            playlistName: recentPlaylist.name,
          }),
          onClick: async () => {
            await appendTracksToPlaylist(
              recentPlaylist.id as UUID,
              selectedTracks,
            );
          },
        });
      }

      return [
        {
          type: "item",
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
          type: "item",
          key: "play_after",
          label: i18next.t("contextMenu.playAfter", {
            defaultValue: "Add To Queue",
            count: selectedTracks.length,
          }),
          onClick() {
            enqueueAfter(selectedTracks);
          },
        },
        {
          type: "divider" as const,
          key: "playlist_actions",
        },
        ...playlistActions,
      ];
    },
    [
      listItems,
      enqueueNext,
      enqueueAfter,
      populateUpNext,
      userConfirmQueueReplace,
      showPlaylistPicker,
      getMostRecentPlaylist,
    ],
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

  if (isFetching) return <Loading />;
  if (error) throw error;
  if (!dataArtist) return;

  const currentAlbum = listItems.find(
    (item) => item.type === "album" && isAlbum(item.album, albumId),
  );

  return (
    <div className="h-full mx-4 lg:mx-8">
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
        resetScrollOnItemsChange={true}
        selectedIds={selectedTrackIds}
        onChange={setSelectedTrackIds}
        onSubmit={onSubmit}
        onDoubleClick={onDoubleClick}
        onContextMenu={onContextMenu}
        renderItem={renderItem}
        paddingBottom={32}
      />
    </div>
  );
}
