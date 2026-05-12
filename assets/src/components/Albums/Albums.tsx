import { useCallback, useState } from "react";
import { Loading } from "../../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { useMediaQuery } from "../../hooks/useMediaQuery";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistPicker } from "../../hooks/usePlaylistPicker";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import { queryTracks, useAlbums } from "../../library";
import type { Album, UUID } from "../../types";
import { appendTracksToPlaylist } from "../../utils/appendTracksToPlaylist";
import { AlbumCard } from "./AlbumCard";

type SortOption = keyof Album & string;

export function Albums({
  currentAlbumId,
  gotoAlbumDetails,
}: {
  currentAlbumId?: UUID;
  gotoAlbumDetails: (album: Album) => void;
}) {
  const gridSize = useMediaQuery("(width >= 48rem)") ? 5 : 2;
  const { populateUpNext, enqueueNext, enqueueAfter, userConfirmQueueReplace } =
    usePlayer();
  const { showPlaylistPicker, getMostRecentPlaylist } = usePlaylistPicker();
  const { showToast } = useToast();
  const [selectedIds, setSelectedIds] = useState<Set<UUID>>(new Set([]));

  const defaultSortOption = (localStorage.getItem("albumSort") ??
    "artistSortName") as SortOption;
  const [sortBy, setSortBy] = useState<SortOption>(defaultSortOption);
  const { data: albums, loading } = useAlbums({ sortBy });

  const renderItem = useCallback((item: Album, state: ListItemState) => {
    return <AlbumCard album={item} isSelected={state.isSelected} />;
  }, []);

  const handleChange = useCallback((selectedIds: Set<UUID>) => {
    setSelectedIds(selectedIds);
  }, []);

  const handleContextMenu = useCallback(
    (selectedIds: Set<UUID>) => {
      const selectedAlbums = albums.filter((album) =>
        selectedIds.has(album.id),
      );
      const selectedAlbumIds = selectedAlbums.map((album) => album.id);
      if (selectedAlbums.length === 0) return [];
      const firstAlbum = selectedAlbums[0];
      const recentPlaylist = getMostRecentPlaylist();
      const playlistActions = [
        {
          type: "item",
          key: "add_to_playlist",
          label: i18next.t("contextMenu.addToPlaylist", {
            defaultValue: "Add To Playlist...",
            count: 12,
          }),
          onClick: async () => {
            const playlist = await showPlaylistPicker();
            if (playlist === false) return;
            const tracks = await queryTracks({ albumIds: selectedAlbumIds });
            await appendTracksToPlaylist(playlist.id, tracks);
            showToast({
              link: `/playlists/${playlist.id}`,
              message: i18next.t("toast.addedToPlaylist", {
                defaultValue: "Added {{ count }} tracks to {{ playlistName }}",
                count: tracks.length,
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
            const tracks = await queryTracks({ albumIds: selectedAlbumIds });
            await appendTracksToPlaylist(recentPlaylist.id as UUID, tracks);
            showToast({
              link: `/playlists/${recentPlaylist.id}`,
              message: i18next.t("toast.addedToPlaylist", {
                defaultValue: "Added {{ count }} tracks to {{ playlistName }}",
                count: tracks.length,
                playlistName: recentPlaylist.name,
              }),
            });
          },
        });
      }

      return [
        {
          type: "item",
          key: "play",
          label: i18next.t("contextMenu.playAlbum", {
            defaultValue: 'Play "{{ album }}"',
            album: firstAlbum.name,
            count: selectedAlbums.length,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ albumIds: selectedAlbumIds });

            showToast({
              message: i18next.t("toast.addedAlbumToPlayNow", {
                defaultValue: "Playing {{ albumName }}",
                albumName: firstAlbum.name,
                count: selectedAlbums.length,
              }),
            });
          },
        },
        {
          type: "item",
          key: "shuffle",
          label: i18next.t("contextMenu.shuffleAlbum", {
            defaultValue: 'Shuffle "{{ album }}"',
            album: firstAlbum.name,
            count: selectedAlbums.length,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ albumIds: selectedAlbumIds, random: true });

            showToast({
              message: i18next.t("toast.addedAlbumToPlayShuffled", {
                defaultValue: "Shuffling {{ albumName }}",
                albumName: firstAlbum.name,
                count: selectedAlbums.length,
              }),
            });
          },
        },
        {
          type: "divider" as const,
          key: "queue_actions",
        },
        {
          type: "item",
          key: "play_next",
          label: i18next.t("contextMenu.playNext", {
            defaultValue: "Play Next",
          }),
          onClick: async () => {
            const tracks = await queryTracks({ albumIds: selectedAlbumIds });
            enqueueNext(tracks.map((track) => ({ track })));

            showToast({
              message: i18next.t("toast.addedToPlayNext", {
                defaultValue: "Added {{ count }} tracks to up next",
                count: tracks.length,
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
          onClick: async () => {
            const tracks = await queryTracks({ albumIds: selectedAlbumIds });
            enqueueAfter(tracks.map((track) => ({ track })));

            showToast({
              message: i18next.t("toast.addedToPlayAfter", {
                defaultValue: "Added {{ count }} tracks to the queue",
                count: tracks.length,
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
      albums,
      userConfirmQueueReplace,
      showToast,
      enqueueNext,
      enqueueAfter,
      populateUpNext,
      showPlaylistPicker,
      getMostRecentPlaylist,
    ],
  );

  const handleSubmit = useCallback(
    async (selectedIds: Set<UUID>) => {
      const selectedAlbums = albums.filter((album) =>
        selectedIds.has(album.id),
      );
      const selectedAlbumIds = selectedAlbums.map((album) => album.id);
      if (selectedAlbums.length === 0) return [];
      const firstAlbum = selectedAlbums[0];

      if (!(await userConfirmQueueReplace())) return;
      populateUpNext({ albumIds: selectedAlbumIds });

      showToast({
        message: i18next.t("toast.addedAlbumToPlayNow", {
          defaultValue: "Playing {{ albumName }}",
          albumName: firstAlbum.name,
          count: selectedAlbums.length,
        }),
      });
    },
    [albums, userConfirmQueueReplace, showToast, populateUpNext],
  );

  if (loading) return <Loading />;

  return (
    <div className="flex flex-col h-full">
      <div className="flex-shrink-0 text-right pb-4">
        <select
          className="text-sm"
          onChange={(e) => {
            const newSortBy = (e.target as HTMLSelectElement)
              .value as SortOption;
            localStorage.setItem("albumSort", newSortBy);
            setSortBy(newSortBy);
          }}
          value={sortBy}
        >
          <option value="artistSortName">Artist</option>
          <option value="sortName">Name</option>
          <option value="releaseYear">Release Year</option>
          <option value="insertedAt">Date Added</option>
        </select>
      </div>
      <div className="h-full overflow-auto">
        <SelectableList<Album>
          id="albums"
          allowDrag={true}
          items={albums}
          gridSize={gridSize}
          gridGapSize={24}
          scrollOverscan={5}
          multiple={true}
          defaultFocusId={currentAlbumId}
          defaultFocusType="center"
          selectedIds={selectedIds}
          onChange={handleChange}
          onContextMenu={handleContextMenu}
          onSubmit={handleSubmit}
          onDoubleClick={gotoAlbumDetails}
          renderItem={renderItem}
        />
      </div>
    </div>
  );
}
