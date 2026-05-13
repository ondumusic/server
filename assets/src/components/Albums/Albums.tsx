import { useCallback, useMemo, useState } from "react";
import { FloatingDropdown } from "../../components/FloatingDropdown";
import { SortAscIcon } from "../../components/icons/SortAscIcon";
import { SortDescIcon } from "../../components/icons/SortDescIcon";
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
import { AlbumRow } from "./AlbumRow";

type SortOption = keyof Album & string;
type SortDirection = "asc" | "desc";

export function Albums({
  currentAlbumId,
  gotoAlbumDetails,
  style: listStyle = "grid",
}: {
  style: "grid" | "list";
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
  const defaultSortDir = (localStorage.getItem("albumSortDir") ??
    "asc") as SortDirection;
  const [sortBy, setSortBy] = useState<SortOption>(defaultSortOption);
  const [sortDir, setSortDir] = useState<SortDirection>(defaultSortDir);
  const sortOptions = useMemo(
    () => [
      {
        value: "artistSortName" as SortOption,
        label: i18next.t("sortBy.album.artistSortName", {
          defaultValue: "Artist",
        }),
        sublabel:
          sortDir === "asc"
            ? i18next.t("sortBy.textAsc", {
                defaultValue: "A-Z",
              })
            : i18next.t("sortBy.textDesc", {
                defaultValue: "Z-A",
              }),
      },
      {
        value: "sortName" as SortOption,
        label: i18next.t("sortBy.album.sortName", {
          defaultValue: "Name",
        }),
        sublabel:
          sortDir === "asc"
            ? i18next.t("sortBy.textAsc", {
                defaultValue: "A-Z",
              })
            : i18next.t("sortBy.textDesc", {
                defaultValue: "Z-A",
              }),
      },
      {
        value: "releaseYear" as SortOption,
        label: i18next.t("sortBy.album.releaseYear", {
          defaultValue: "Release Year",
        }),
        sublabel:
          sortDir === "asc"
            ? i18next.t("sortBy.dateAsc", {
                defaultValue: "Oldest First",
              })
            : i18next.t("sortBy.dateDesc", {
                defaultValue: "Newest First",
              }),
      },
      {
        value: "insertedAt" as SortOption,
        label: i18next.t("sortBy.album.insertedAt", {
          defaultValue: "Date Added",
        }),
        sublabel:
          sortDir === "asc"
            ? i18next.t("sortBy.dateAsc", {
                defaultValue: "Oldest First",
              })
            : i18next.t("sortBy.dateDesc", {
                defaultValue: "Newest First",
              }),
      },
    ],
    [sortDir],
  );
  const currentSortOption =
    sortOptions.find(({ value }) => value === sortBy) ?? sortOptions[0];

  const { data: albums, loading } = useAlbums({ sortBy, sortDir });

  const renderItem = useCallback(
    (item: Album, state: ListItemState) => {
      if (listStyle === "grid") {
        return <AlbumCard album={item} isSelected={state.isSelected} />;
      } else if (listStyle === "list") {
        return <AlbumRow album={item} isSelected={state.isSelected} />;
      }
    },
    [listStyle],
  );

  const handleChange = useCallback(
    (selectedIds: Set<UUID>) => {
      if (listStyle === "grid") {
        setSelectedIds(selectedIds);
      } else {
        const selectedAlbum = albums.find((album) => selectedIds.has(album.id));
        if (!selectedAlbum) return;
        gotoAlbumDetails(selectedAlbum);
      }
    },
    [albums, listStyle, gotoAlbumDetails],
  );

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

  const handleDoubleClick = useCallback(
    (album: Album) => {
      if (listStyle === "grid") {
        gotoAlbumDetails(album);
      } else {
        handleSubmit(new Set([album.id]));
      }
    },
    [listStyle, gotoAlbumDetails, handleSubmit],
  );

  if (loading) return <Loading />;

  return (
    <div className="flex flex-col h-full">
      {listStyle === "grid" && (
        <div className="fixed top-0 right-4 flex-shrink-0 text-right z-[1000]">
          <FloatingDropdown<SortOption>
            onChange={(value) => {
              if (sortBy === value) {
                const newSortDir = sortDir === "asc" ? "desc" : "asc";
                setSortDir(newSortDir);
                localStorage.setItem("albumSortDir", newSortDir);
              } else {
                localStorage.setItem("albumSort", value);
                setSortBy(value);
              }
            }}
            value={sortBy}
            options={sortOptions}
          >
            {currentSortOption?.label}
            {sortDir === "asc" ? (
              <SortAscIcon className="size-5" title="" />
            ) : (
              <SortDescIcon className="size-5" title="" />
            )}
          </FloatingDropdown>
        </div>
      )}
      <div className="h-full overflow-auto">
        <SelectableList<Album>
          id="albums"
          allowDrag={true}
          items={albums}
          gridSize={listStyle === "grid" ? gridSize : 1}
          gridGapSize={listStyle === "grid" ? 24 : 0}
          scrollOverscan={listStyle === "grid" ? 5 : 10}
          multiple={listStyle === "grid"}
          paddingTop={listStyle === "grid" ? 58 : 10}
          paddingBottom={listStyle === "grid" ? 0 : 10}
          defaultFocusId={currentAlbumId}
          defaultFocusType="nearest"
          selectedIds={
            listStyle === "grid"
              ? selectedIds
              : new Set(currentAlbumId ? [currentAlbumId] : [])
          }
          onChange={handleChange}
          onContextMenu={handleContextMenu}
          onSubmit={handleSubmit}
          onDoubleClick={handleDoubleClick}
          renderItem={renderItem}
        />
      </div>
    </div>
  );
}
