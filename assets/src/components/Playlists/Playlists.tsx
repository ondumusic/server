import {
  type PropsWithChildren,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { playlistApi } from "../../api";
import { Loading } from "../../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import type { ContextMenuItem } from "../../hooks/useContextMenu";
import { usePlayer } from "../../hooks/usePlayer";
import { maybeResetPlaylistPicker } from "../../hooks/usePlaylistPicker";
import i18next from "../../i18next";
import { sync, usePlaylists } from "../../library";
import type { Playlist, UUID } from "../../types";
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
  onCreate,
  onChange,
  onDelete,
  onSubmit,
}: PropsWithChildren<{
  playlistId?: UUID;
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
    (selectedIds: Set<string>) => {
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
    async (selectedIds: Set<string>) => {
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
    (selectedIds: Set<string>): ContextMenuItem[] => {
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
          deletePlaylist,
        ];
      }

      return [
        {
          type: "item",
          key: "play_next",
          label: i18next.t("contextMenu.playPlaylist", {
            defaultValue: 'Play "{{ playlist }}"',
            playlist: playlist.name,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ playlistId: playlist.id });
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
          },
        },
        {
          type: "divider",
          key: "destructive",
        },
        renamePlaylist,
        deletePlaylist,
      ];
    },
    [
      listItems,
      userConfirmQueueReplace,
      populateUpNext,
      handleDelete,
      openFolders,
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
    async (selectedIds: Set<string>) => {
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return;
      handleDoubleClick(playlist);
    },
    [listItems, handleDoubleClick],
  );

  const renderItem = useCallback(
    (playlist: ListItem, state: ListItemState) => (
      <PlaylistRow isSelected={state.isSelected} playlist={playlist} />
    ),
    [],
  );

  if (isLoading) return <Loading />;

  const currentPlaylist = playlistId
    ? listItems.find((playlist) => isPlaylist(playlist, playlistId))
    : undefined;

  return (
    <SelectableList<ListItem>
      multiple={false}
      items={listItems}
      paddingTop={10}
      paddingBottom={10}
      defaultFocusId={currentPlaylist?.id}
      onTypeMatch={handleTypeMatch}
      defaultFocusType="center"
      selectedIds={
        currentPlaylist ? new Set([currentPlaylist.id]) : new Set([])
      }
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
  );
}
