import { useNavigate } from "@tanstack/react-router";
import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { usePlayer } from "../../hooks/usePlayer";
import { usePlaylistPicker } from "../../hooks/usePlaylistPicker";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import { queryTracks } from "../../library";
import type { Album, UUID } from "../../types";
import { appendTracksToPlaylist } from "../../utils/appendTracksToPlaylist";
import { AlbumCard } from "../Albums/AlbumCard";
import { type ListItemState, SelectableList } from "../SelectableList";

interface Props {
  albums: Album[];
}

const minCardWidth = 120;
const gapSize = 18;

export function AlbumResults({ albums }: Props) {
  const navigate = useNavigate();
  const { populateUpNext, enqueueNext, enqueueAfter, userConfirmQueueReplace } =
    usePlayer();
  const { showPlaylistPicker, getMostRecentPlaylist } = usePlaylistPicker();
  const { showToast } = useToast();
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerWidth, setContainerWidth] = useState(0);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  // Clears the selection when the results change.
  // biome-ignore lint/correctness/useExhaustiveDependencies(albums): only used to trigger a reset
  useEffect(() => {
    setSelectedIds(new Set());
  }, [albums]);

  // Get the available width so we can use it to calculate the gridSize
  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    setContainerWidth(container.clientWidth);
    const observer = new ResizeObserver(() => {
      setContainerWidth(container.clientWidth);
    });
    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  // We only want to show one row of items in this grid
  const gridSize = Math.max(
    1,
    Math.floor((containerWidth + gapSize) / (minCardWidth + gapSize)),
  );
  const visibleAlbums = useMemo(
    () => albums.slice(0, gridSize),
    [albums, gridSize],
  );

  const handleSubmit = useCallback(
    async (ids: Set<UUID>) => {
      const selected = albums.filter((album) => ids.has(album.id));
      if (!selected.length) return;
      if (!(await userConfirmQueueReplace())) return;

      populateUpNext({ albumIds: selected.map((album) => album.id) });
      showToast({
        message: i18next.t("toast.addedAlbumToPlayNow", {
          defaultValue: "Playing {{ albumName }}",
          albumName: selected[0].name,
          count: selected.length,
        }),
      });
    },
    [albums, populateUpNext, userConfirmQueueReplace, showToast],
  );

  const handleDoubleClick = useCallback(
    (album: Album) => {
      navigate({ to: "/albums/$albumId", params: { albumId: album.id } });
    },
    [navigate],
  );

  const handleContextMenu = useCallback(
    (ids: Set<UUID>) => {
      const selectedAlbums = albums.filter((album) => ids.has(album.id));
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

  const renderItem = useCallback((album: Album, state: ListItemState) => {
    return <AlbumCard album={album} isSelected={state.isSelected} />;
  }, []);

  return (
    <div className="px-2">
      <div ref={containerRef}>
        <SelectableList<Album>
          id="albums"
          multiple
          allowDrag
          allowDropFrom={[]}
          items={visibleAlbums}
          gridSize={gridSize}
          gridGapSize={gapSize}
          selectedIds={selectedIds}
          onChange={setSelectedIds}
          onSubmit={handleSubmit}
          onDoubleClick={handleDoubleClick}
          onContextMenu={handleContextMenu}
          renderItem={renderItem}
        />
      </div>
    </div>
  );
}
