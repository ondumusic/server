import {
  type PropsWithChildren,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { playlistApi } from "../../api";
import { PlusIcon } from "../../components/icons/PlusIcon";
import { Loading } from "../../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import type { ContextMenuItem } from "../../hooks/useContextMenu";
import { usePlayer } from "../../hooks/usePlayer";
import { maybeResetPlaylistPicker } from "../../hooks/usePlaylistPicker";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import {
  queryPlaylistItemsByIds,
  queryTracksByIds,
  sync,
  usePlaylists,
} from "../../library";
import type { Playlist, Track, UUID } from "../../types";
import { appendTracksToPlaylist } from "../../utils/appendTracksToPlaylist";
import { type ListItem, PlaylistRow } from "./PlaylistRow";

function isPlaylist(playlist: Playlist, playlistId: string): boolean {
  return playlist.id === playlistId;
}

interface PendingPlaylist {
  parentId?: UUID;
  isFolder?: boolean;
}

export function Playlists({
  playlistId,
  paddingTop = 10,
  showBottomBar = false,
  allowPlayback = true,
  allowDelete = true,
  onCreate,
  onChange,
  onDelete,
  onSubmit,
}: PropsWithChildren<{
  playlistId?: UUID;
  paddingTop?: number;
  showBottomBar?: boolean;
  allowPlayback?: boolean;
  allowDelete?: boolean;
  onCreate?: (playlist: Playlist) => void;
  onChange?: (playlist: Playlist) => void;
  onDelete?: (playlist: Playlist) => void;
  onSubmit?: (playlist: Playlist) => void;
}>) {
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const { data: allItems, loading: isLoading } = usePlaylists({
    includeAll: true,
  });
  const [openFolders, setOpenFolders] = useState<Set<UUID>>(new Set());
  const [renamingPlaylist, setRenamingPlaylist] = useState<UUID | false>(false);
  const [creatingPlaylist, setCreatingPlaylist] = useState<
    PendingPlaylist | false
  >(false);
  const { showToast } = useToast();

  // Pre-open folders if the playlistId from route params is available
  useEffect(() => {
    if (!playlistId || allItems.length === 0) return;

    const byId = new Map(allItems.map((item) => [item.id, item]));
    let current = byId.get(playlistId);
    const ancestors = new Set<UUID>();

    while (current?.parentId) {
      ancestors.add(current.parentId);
      current = byId.get(current.parentId);
    }

    setOpenFolders((prev) => new Set<UUID>([...prev, ...ancestors]));
  }, [allItems, playlistId]);

  // Render a "file tree" type view
  const listItems = useMemo((): ListItem[] => {
    const byParent = new Map();
    for (const playlist of allItems) {
      const key = playlist.parentId ?? null;
      if (!byParent.has(key)) byParent.set(key, []);
      byParent.get(key).push(playlist);
    }

    // Recursive to apply correct indenting levels
    const buildTree = (parentId: UUID | null, indentLevel: number) => {
      const children = byParent.get(parentId ?? null) ?? [];
      const tree = children.flatMap((playlist: Playlist) => {
        let node = {
          ...playlist,
          editing: renamingPlaylist === playlist.id,
          indentLevel,
        } as ListItem;

        if (node.editing) {
          node = {
            ...node,
            onCancel: () => {
              setRenamingPlaylist(false);
            },
            onConfirm: async (name: string) => {
              const updatedPlaylist = await playlistApi.updatePlaylist(
                playlist.id,
                {
                  name,
                },
              );

              maybeResetPlaylistPicker(
                updatedPlaylist.id,
                updatedPlaylist.name,
              );

              await sync.pushChanges({
                playlists: [updatedPlaylist],
              });

              setRenamingPlaylist(false);
            },
          };
        }

        if (playlist.isFolder && openFolders.has(playlist.id)) {
          return [node, ...buildTree(playlist.id, indentLevel + 1)];
        }
        return [node];
      });

      if (creatingPlaylist === false) return tree;

      if (
        (!creatingPlaylist?.parentId && !parentId) ||
        creatingPlaylist?.parentId === parentId
      ) {
        tree.push({
          id: "new",
          editing: true,
          indentLevel,
          isFolder: creatingPlaylist.isFolder === true,
          name: "",
          onCancel: () => {
            setCreatingPlaylist(false);
          },
          onConfirm: async (name: string) => {
            const newPlaylist = await playlistApi.createPlaylist({
              name,
              isFolder: creatingPlaylist.isFolder === true,
              parentId: creatingPlaylist.parentId,
            });

            setCreatingPlaylist(false);

            await sync.pushChanges({
              playlists: [newPlaylist],
            });

            if (typeof onCreate === "function") {
              onCreate(newPlaylist);
            }
          },
        });
      }

      return tree;
    };

    return buildTree(null, 0);
  }, [allItems, creatingPlaylist, renamingPlaylist, openFolders, onCreate]);

  const handleTypeMatch = useCallback((item: Playlist, query: string) => {
    const matcher = new RegExp(`^${query.replace(/\s+/g, "")}`, "iu");
    const name = item.name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/\s+/g, "");

    return name.match(matcher) !== null;
  }, []);

  const handleChange = useCallback(
    (selectedIds: Set<UUID>) => {
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return;

      if (typeof onChange === "function") {
        onChange(playlist);
      }
    },
    [listItems, onChange],
  );

  const handleDelete = useCallback(
    async (selectedIds: Set<UUID>) => {
      if (selectedIds.size !== 1) return;
      const playlist = listItems.find((p) => selectedIds.has(p.id));
      if (!playlist) return;

      if (typeof onDelete === "function") {
        onDelete(playlist);
      }
    },
    [listItems, onDelete],
  );

  const handleContextMenu = useCallback(
    (selectedIds: Set<UUID>): ContextMenuItem[] => {
      const createPlaylist = {
        type: "item",
        key: "create_playlist",
        label: i18next.t("contextMenu.createPlaylist", {
          defaultValue: "Create Playlist",
        }),
        onClick: async () => {
          setCreatingPlaylist({
            isFolder: false,
          });
        },
      };

      const createFolder = {
        type: "item",
        key: "create_folder",
        label: i18next.t("contextMenu.createPlaylistFolder", {
          defaultValue: "Create Folder",
        }),
        onClick: async () => {
          setCreatingPlaylist({
            isFolder: true,
          });
        },
      };

      if (selectedIds.size === 0) {
        return [createPlaylist, createFolder];
      }

      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return [];
      if (playlist.id === "new") return [];

      const renamePlaylist = {
        type: "item",
        key: "rename_playlist",
        label: i18next.t("contextMenu.renamePlaylist", {
          defaultValue: "Rename",
        }),
        onClick: async () => {
          setRenamingPlaylist(playlist.id);
        },
      };

      const deletePlaylist = {
        type: "item",
        key: "delete_playlist",
        danger: true,
        label: i18next.t("contextMenu.deletePlaylist", {
          defaultValue: 'Delete "{{ playlist }}"',
          playlist: playlist.name,
        }),
        onClick: async () => {
          await handleDelete(new Set([playlist.id]));
        },
      };

      if (playlist.isFolder) {
        return [
          {
            ...createPlaylist,
            onClick: async () => {
              openFolders.add(playlist.id);
              setOpenFolders(new Set([...openFolders]));
              setCreatingPlaylist({
                isFolder: false,
                parentId: playlist.id,
              });
            },
          },
          {
            ...createFolder,
            onClick: async () => {
              openFolders.add(playlist.id);
              setOpenFolders(new Set([...openFolders]));
              setCreatingPlaylist({
                isFolder: true,
                parentId: playlist.id,
              });
            },
          },
          {
            type: "divider",
            key: "destructive",
          },
          renamePlaylist,
          allowDelete ? deletePlaylist : undefined,
        ].filter((item) => !!item) as ContextMenuItem[];
      }

      let playbackControls: ContextMenuItem[] = [
        createPlaylist,
        createFolder,
        {
          type: "divider",
          key: "destructive",
        },
      ];
      if (allowPlayback) {
        playbackControls = [
          {
            type: "item",
            key: "play",
            label: i18next.t("contextMenu.playPlaylist", {
              defaultValue: 'Play "{{ playlist }}"',
              playlist: playlist.name,
            }),
            onClick: async () => {
              if (!(await userConfirmQueueReplace())) return;
              populateUpNext({ playlistId: playlist.id });

              showToast({
                message: i18next.t("toast.addedPlaylistToPlayNow", {
                  defaultValue: "Playing {{ playlistName }}",
                  playlistName: playlist.name,
                }),
              });
            },
          },
          {
            type: "item",
            key: "play_after",
            label: i18next.t("contextMenu.shufflePlaylist", {
              defaultValue: 'Shuffle "{{ playlist }}"',
              playlist: playlist.name,
            }),
            onClick: async () => {
              if (!(await userConfirmQueueReplace())) return;
              populateUpNext({ playlistId: playlist.id, random: true });

              showToast({
                message: i18next.t("toast.addedPlaylistToPlayShuffled", {
                  defaultValue: "Shuffling {{ playlistName }}",
                  playlistName: playlist.name,
                }),
              });
            },
          },
          {
            type: "divider",
            key: "destructive",
          },
        ];
      }

      return [
        ...playbackControls,
        renamePlaylist,
        allowDelete ? deletePlaylist : undefined,
      ].filter((item) => !!item);
    },
    [
      listItems,
      userConfirmQueueReplace,
      populateUpNext,
      handleDelete,
      openFolders,
      showToast,
      allowPlayback,
      allowDelete,
    ],
  );

  const handleDoubleClick = useCallback(
    async (playlist: Playlist) => {
      if (playlist.isFolder) {
        if (!openFolders.has(playlist.id)) {
          openFolders.add(playlist.id);
          setOpenFolders(new Set([...openFolders]));
        } else {
          openFolders.delete(playlist.id);
          setOpenFolders(new Set([...openFolders]));
        }
        return;
      }

      if (typeof onSubmit === "function") {
        onSubmit(playlist);
      }
    },
    [openFolders, onSubmit],
  );

  const handleSubmit = useCallback(
    async (selectedIds: Set<UUID>) => {
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return;
      handleDoubleClick(playlist);
    },
    [listItems, handleDoubleClick],
  );

  const changePlaylistParent = useCallback(
    async (playlistId: UUID, parentId: UUID | null) => {
      const updatedPlaylist = await playlistApi.updatePlaylist(playlistId, {
        parentId,
      });
      await sync.pushChanges({
        playlists: [updatedPlaylist],
      });
    },
    [],
  );

  const handlePlaylistMove = useCallback(
    async (selectedIds: Set<UUID>, insertAtIndex: number) => {
      const rootFolder = insertAtIndex === listItems.length;
      const selectedId = Array.from(selectedIds).pop();
      const playlist = allItems.find((folder) => folder.id === selectedId);
      if (!playlist) return;

      if (rootFolder) {
        if (!playlist.parentId) return; // already in root
        await changePlaylistParent(playlist.id, null);
      } else {
        const targetFolder = listItems[insertAtIndex];
        const targetFolderId = targetFolder?.isFolder
          ? targetFolder?.id
          : targetFolder?.parentId;

        if (!targetFolderId) {
          if (!playlist.parentId) return; // already in root
          await changePlaylistParent(playlist.id, null);
        } else {
          const target = allItems.find(
            (folder) => folder.id === targetFolderId,
          );
          if (!target) return;
          if (playlist.parentId === target.id) return; // already in folder
          await changePlaylistParent(playlist.id, target.id);
        }
      }
    },
    [allItems, listItems, changePlaylistParent],
  );

  const handleDrop = useCallback(
    async (
      selectedIds: Set<UUID>,
      insertAtIndex: number,
      sourceListId: string,
    ) => {
      if (sourceListId === "playlists") {
        await handlePlaylistMove(selectedIds, insertAtIndex);
        return;
      }

      // Can't drop tracks on folders or non plaaylist
      const targetPlaylist = listItems[insertAtIndex];
      if (!targetPlaylist || targetPlaylist?.isFolder) return;

      let tracks: Track[] = [];
      if (sourceListId === "playlist") {
        const playlistItems = await queryPlaylistItemsByIds(
          Array.from(selectedIds),
        );
        tracks = playlistItems
          .map((item) => item.track as Track)
          .filter((t) => !!t);
      } else if (sourceListId === "upNext") {
        const trackIds = [...selectedIds].map((queueId) => {
          return queueId.split("/").shift() as UUID;
        });
        tracks = await queryTracksByIds(trackIds);
      }

      if (tracks.length === 0) return;
      await appendTracksToPlaylist(targetPlaylist.id, tracks);
      showToast({
        link: `/playlists/${targetPlaylist.id}`,
        message: i18next.t("toast.addedToPlaylist", {
          defaultValue: "Added {{ count }} tracks to {{ playlistName }}",
          count: tracks.length,
          playlistName: targetPlaylist.name,
        }),
      });
    },
    [listItems, showToast, handlePlaylistMove],
  );

  const renderItem = useCallback(
    (playlist: ListItem, state: ListItemState) => (
      <PlaylistRow
        isSelected={state.isSelected}
        isDropTarget={state.isDropTarget}
        playlist={playlist}
      />
    ),
    [],
  );

  if (isLoading) return <Loading />;

  const currentPlaylist = playlistId
    ? listItems.find((playlist) => isPlaylist(playlist, playlistId))
    : undefined;

  return (
    <div className="flex flex-col h-full">
      <div className="h-full overflow-auto">
        <SelectableList<ListItem>
          id="playlists"
          allowDrag={true}
          allowDropFrom={["playlists", "playlist", "upNext"]}
          dropTargetType="item"
          dropTargetClass="bg-transparent"
          onDrop={handleDrop}
          multiple={false}
          items={listItems}
          paddingTop={paddingTop}
          paddingBottom={10}
          defaultFocusId={currentPlaylist?.id}
          onTypeMatch={handleTypeMatch}
          defaultFocusType="center"
          selectedIds={new Set(currentPlaylist ? [currentPlaylist.id] : [])}
          keyBindings={{
            ArrowRight: ({ focusedItem }) => {
              if (!focusedItem?.isFolder) return;
              openFolders.add(focusedItem.id);
              setOpenFolders(new Set([...openFolders]));
            },
            ArrowLeft: ({ focusedItem }) => {
              if (!focusedItem?.isFolder) return;
              openFolders.delete(focusedItem.id);
              setOpenFolders(new Set([...openFolders]));
            },
          }}
          onContextMenu={handleContextMenu}
          onChange={handleChange}
          onDelete={handleDelete}
          onSubmit={handleSubmit}
          onDoubleClick={handleDoubleClick}
          renderItem={renderItem}
        />
      </div>
      {showBottomBar && (
        <div className="px-2 py-2">
          <button
            className="flex items-center gap-2 w-full rounded-md cursor-pointer py-1.5 px-2 justify-start text-sm font-medium text-accent-500 hover:text-accent-600"
            type="button"
            onClick={() => {
              setCreatingPlaylist({
                isFolder: false,
              });
            }}
          >
            <PlusIcon title="New Playlist" className="size-5" />
            {i18next.t("contextMenu.createPlaylist", {
              defaultValue: "Create Playlist",
            })}
          </button>
        </div>
      )}
    </div>
  );
}
