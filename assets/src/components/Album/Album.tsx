import { useCallback, useEffect, useMemo, useState } from "react";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { TrackRow } from "../../components/Tracks";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistPicker } from "../../hooks/usePlaylistPicker";
import { useQueue } from "../../hooks/useQueue";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import type { Album as TAlbum, Track, UUID } from "../../types";
import { appendTracksToPlaylist } from "../../utils/appendTracksToPlaylist";
import { splitTracksByDisc } from "../../utils/splitTracksByDisc";
import { AlbumHeader } from "./AlbumHeader";
import { DiscRow } from "./DiscRow";
import { PlaceholderRow } from "./PlaceholderRow";
import type { ListItem } from "./types";

export function Album({ album, tracks }: { album: TAlbum; tracks: Track[] }) {
  const { showToast } = useToast();
  const { showPlaylistPicker, getMostRecentPlaylist } = usePlaylistPicker();
  const { enqueueAndPlay, enqueueNext, enqueueAfter, userConfirmQueueReplace } =
    usePlayer();

  const { currentTrack } = useQueue();

  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set(),
  );

  // Reset selection on album change
  // biome-ignore lint/correctness/useExhaustiveDependencies(album.id): dont need it
  useEffect(() => {
    setSelectedTrackIds(new Set());
  }, [album.id]);

  const listItems = useMemo(() => {
    const tracksPerDisc = splitTracksByDisc(tracks);
    const showDiscNumbers = tracksPerDisc.length > 1;
    const showTrackArtist =
      new Set(tracks.map((track) => track.artistId)).size > 1;

    const items: ListItem[] = [
      {
        type: "header",
        id: "header",
        selectable: false,
        album,
        tracks,
      },
      ...tracksPerDisc.flatMap((disc, discIndex): ListItem[] => {
        const trackCount = disc.tracks.length;

        // Convert track to TrackItem
        const discTracks = disc.tracks.flatMap(
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

        if (showDiscNumbers) {
          discTracks.unshift({
            id: `${album.id}-disc-${disc.number}`,
            type: "disc" as const,
            selectable: false,
            disc,
          });

          // Add whitespace between previous disc and this disc
          if (discIndex !== 0) {
            discTracks.unshift({
              id: `${album.id}-placeholder-disc-${disc.number}`,
              selectable: false,
              type: "placeholder" as const,
            });
          }
        }

        return discTracks;
      }),
    ];

    return items;
  }, [tracks, album]);

  const handleSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;
      const selectedTracks = tracks.filter((track) =>
        selectedIds.has(track.id),
      );
      if (selectedTracks.length === 1) {
        const selectedTrack = selectedTracks[0];

        // Add all tracks and start at selected track
        const queueItems = selectedTracks.map((track) => ({ track }));

        const startWithItem = queueItems.find((queueItem) => {
          return queueItem.track.id === selectedTrack.id;
        });

        enqueueAndPlay(queueItems, startWithItem);
      } else {
        enqueueAndPlay(selectedTracks.map((track) => ({ track })));
      }
    },
    [tracks, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleDoubleClick = useCallback(
    async (item: ListItem) => {
      if (item.type !== "track") return;
      if (!(await userConfirmQueueReplace())) return;

      // Add all tracks and start at selected track
      const queueItems = tracks.map((track) => ({ track }));

      const startWithItem = queueItems.find((queueItem) => {
        return queueItem.track.id === item.id;
      });

      enqueueAndPlay(queueItems, startWithItem);
    },
    [tracks, enqueueAndPlay, userConfirmQueueReplace],
  );

  const handleContextMenu = useCallback(
    (selectedIds: Set<string>) => {
      const recentPlaylist = getMostRecentPlaylist();
      const selectedTracks = tracks.filter((track) =>
        selectedIds.has(track.id),
      );
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
      tracks,
      enqueueNext,
      enqueueAfter,
      showPlaylistPicker,
      getMostRecentPlaylist,
      showToast,
    ],
  );

  const renderItem = useCallback(
    (item: ListItem, state: ListItemState) => {
      switch (item.type) {
        case "header":
          return <AlbumHeader {...item} />;

        case "disc":
          return <DiscRow item={item} />;

        case "placeholder":
          return <PlaceholderRow item={item} />;

        case "track":
          return (
            <TrackRow
              track={item.track}
              number={item.track.number}
              isSelected={state.isSelected}
              isPlaying={item.id === currentTrack?.id}
              isDragging={state.isDragging}
              isLastTrack={item.lastTrackOnDisc}
              showTrackArtist={item.showTrackArtist}
              showAlbumArtwork={false}
            />
          );
      }
    },
    [currentTrack],
  );

  return (
    <SelectableList<ListItem>
      multiple
      allowDrag
      allowDropFrom={[]}
      id="albumTracks"
      items={listItems}
      renderItem={renderItem}
      selectedIds={selectedTrackIds}
      onChange={setSelectedTrackIds}
      onSubmit={handleSubmit}
      onDoubleClick={handleDoubleClick}
      onContextMenu={handleContextMenu}
      paddingBottom={32}
    />
  );
}
