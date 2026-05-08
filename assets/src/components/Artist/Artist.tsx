import { useCallback, useEffect, useMemo, useState } from "react";

import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistPicker } from "../../hooks/usePlaylistPicker";
import { useQueue } from "../../hooks/useQueue";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import type { Album, Artist as TArtist, Track, UUID } from "../../types";
import { appendTracksToPlaylist } from "../../utils/appendTracksToPlaylist";
import { splitTracksByDisc } from "../../utils/splitTracksByDisc";

import { ArtistAlbumDiscRow } from "./ArtistAlbumDiscRow";
import { ArtistAlbumRow } from "./ArtistAlbumRow";
import { ArtistAlbumTrackRow } from "./ArtistAlbumTrackRow";
import { ArtistHeaderRow } from "./ArtistHeaderRow";
import { PlaceholderRow } from "./PlaceholderRow";
import type { ListItem } from "./types";

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

interface Props {
  artist: TArtist;
  currentAlbumId?: UUID;
  albums: Album[];
}

export function Artist({ artist, currentAlbumId, albums }: Props) {
  const artistId = artist.id;
  const { showToast } = useToast();
  const { showPlaylistPicker, getMostRecentPlaylist } = usePlaylistPicker();
  const {
    enqueueAndPlay,
    enqueueNext,
    enqueueAfter,
    populateUpNext,
    userConfirmQueueReplace,
  } = usePlayer();

  const { currentTrack } = useQueue();
  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set(),
  );

  // Reset selection on artist/album change
  // biome-ignore lint/correctness/useExhaustiveDependencies(artistId): dont need it
  // biome-ignore lint/correctness/useExhaustiveDependencies(currentAlbumId): dont need it
  useEffect(() => {
    setSelectedTrackIds(new Set());
  }, [artistId, currentAlbumId]);

  const listItems: ListItem[] = useMemo(() => {
    if (!artist || !albums) return [];

    return [
      {
        id: "artistHeader",
        type: "artist" as const,
        selectable: false,
        artist: artist,
      },
      ...albums.flatMap((album, albumIndex) => {
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
  }, [albums, artist]);

  const handlePlayAlbum = useCallback(
    async (item: ListItem) => {
      if (item.type !== "album") return;
      if (!(await userConfirmQueueReplace())) return;

      const albumTracks = albums
        .flatMap((album) => {
          if (album.id !== item.album.id) return [];
          return album.tracks;
        })
        .map((track) => ({ track }));

      enqueueAndPlay(albumTracks);
    },
    [albums, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;
      const selectedTracks = getTracksById(listItems, selectedIds);
      if (selectedTracks.length === 1) {
        const selectedTrack = selectedTracks[0];

        // The default behaviour we want is to add all tracks from the same
        // album to the queue and start playback at the selected track.
        const queueItems = albums
          .flatMap((album) => {
            if (album.id !== selectedTrack.albumId) return [];
            return album.tracks;
          })
          .map((track) => ({ track }));

        const startWithItem = queueItems.find((queueItem) => {
          return queueItem.track.id === selectedTrack.id;
        });

        enqueueAndPlay(queueItems, startWithItem);
      } else {
        enqueueAndPlay(selectedTracks.map((track) => ({ track })));
      }
    },
    [listItems, albums, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleDoubleClick = useCallback(
    async (item: ListItem) => {
      if (item.type !== "track") return;
      if (!(await userConfirmQueueReplace())) return;

      // The default behaviour we want is to add all tracks from the same
      // album to the queue and start playback at the selected track.
      const queueItems = albums
        .flatMap((album) => {
          if (album.id !== item.track.albumId) return [];
          return album.tracks;
        })
        .map((track) => ({ track }));

      const startWithItem = queueItems.find((queueItem) => {
        return queueItem.track.id === item.id;
      });

      enqueueAndPlay(queueItems, startWithItem);
    },
    [albums, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleContextMenu = useCallback(
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
              const playlist = await showPlaylistPicker();
              if (playlist === false) return;
              await appendTracksToPlaylist(playlist.id, album.tracks);
              showToast({
                link: `/playlists/${playlist.id}`,
                message: i18next.t("toast.addedToPlaylist", {
                  defaultValue:
                    "Added {{ count }} tracks to {{ playlistName }}",
                  count: album.tracks.length,
                  playlistName: playlist.name,
                }),
              });
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
              showToast({
                link: `/playlists/${recentPlaylist.id}`,
                message: i18next.t("toast.addedToPlaylist", {
                  defaultValue:
                    "Added {{ count }} tracks to {{ playlistName }}",
                  count: album.tracks.length,
                  playlistName: recentPlaylist.name,
                }),
              });
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
              enqueueNext(album.tracks.map((track) => ({ track })));

              showToast({
                message: i18next.t("toast.addedToPlayNext", {
                  defaultValue: "Added {{ count }} tracks to up next",
                  count: album.tracks.length,
                }),
              });
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
              enqueueAfter(album.tracks.map((track) => ({ track })));

              showToast({
                message: i18next.t("toast.addedToPlayAfter", {
                  defaultValue: "Added {{ count }} tracks to the queue",
                  count: album.tracks.length,
                }),
              });
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

              showToast({
                message: i18next.t("toast.addedToPlayShuffled", {
                  defaultValue: "Shuffling {{ count }} tracks",
                  count: album.tracks.length,
                }),
              });
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
            const playlist = await showPlaylistPicker();
            if (playlist === false) return;
            await appendTracksToPlaylist(playlist.id, selectedTracks);
            showToast({
              link: `/playlists/${playlist.id}`,
              message: i18next.t("toast.addedToPlaylist", {
                defaultValue: "Added {{ count }} tracks to {{ playlistName }}",
                count: selectedTracks.length,
                playlistName: playlist.name,
              }),
            });
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
            showToast({
              link: `/playlists/${recentPlaylist.id}`,
              message: i18next.t("toast.addedToPlaylist", {
                defaultValue: "Added {{ count }} tracks to {{ playlistName }}",
                count: selectedTracks.length,
                playlistName: recentPlaylist.name,
              }),
            });
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
            enqueueNext(selectedTracks.map((track) => ({ track })));

            showToast({
              message: i18next.t("toast.addedToPlayNext", {
                defaultValue: "Added {{ count }} tracks to up next",
                count: selectedTracks.length,
              }),
            });
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
            enqueueAfter(selectedTracks.map((track) => ({ track })));

            showToast({
              message: i18next.t("toast.addedToPlayAfter", {
                defaultValue: "Added {{ count }} tracks to the queue",
                count: selectedTracks.length,
              }),
            });
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
      showToast,
    ],
  );

  const renderItem = useCallback(
    (item: ListItem, state: ListItemState) => {
      switch (item.type) {
        case "artist":
          return <ArtistHeaderRow item={item} />;
        case "album":
          return <ArtistAlbumRow item={item} onPlayAlbum={handlePlayAlbum} />;
        case "disc":
          return <ArtistAlbumDiscRow item={item} />;
        case "track":
          return (
            <ArtistAlbumTrackRow
              item={item}
              isDragging={state.isDragging}
              isSelected={state.isSelected}
              isPlaying={item.id === currentTrack?.id}
            />
          );
        case "placeholder":
          return <PlaceholderRow item={item} />;
      }
    },
    [handlePlayAlbum, currentTrack],
  );

  const currentAlbum = listItems.find(
    (item) => item.type === "album" && isAlbum(item.album, currentAlbumId),
  );

  return (
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
      onSubmit={handleSubmit}
      onDoubleClick={handleDoubleClick}
      onContextMenu={handleContextMenu}
      renderItem={renderItem}
      paddingBottom={32}
    />
  );
}
