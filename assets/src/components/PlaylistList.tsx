import { useNavigate } from "@tanstack/react-router";
import {
  type PropsWithChildren,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { playlistApi } from "../api";
import { Loading } from "../components/Loading";
import {
  type ListItem,
  PlaylistListItem,
} from "../components/PlaylistListItem";
import {
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import type { ContextMenuItem } from "../hooks/useContextMenu";
import { useDialog } from "../hooks/useDialog";
import { usePlayer } from "../hooks/usePlayer";
import i18next from "../i18next";
import { sync, usePlaylists } from "../library";
import type { Playlist, UUID } from "../types";

function isPlaylist(playlist: Playlist, playlistId: string): boolean {
  return playlist.id === playlistId;
}

interface PendingPlaylist {
  parentId?: UUID;
  isFolder?: boolean;
}

export function PlaylistList({
  playlistId,
}: PropsWithChildren<{
  playlistId?: UUID;
}>) {
  const navigate = useNavigate();
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const { promptConfirm } = useDialog();
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

            navigate({
              to: `/playlists/${newPlaylist.id}`,
              params: { playlistId: newPlaylist.id },
            });
          },
        });
      }

      return tree;
    };

    return buildTree(null, 0);
  }, [allItems, creatingPlaylist, renamingPlaylist, openFolders, navigate]);

  const onTypeMatch = useCallback((item: Playlist, query: string) => {
    const matcher = new RegExp(`^${query.replace(/\s+/g, "")}`, "iu");
    const name = item.name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/\s+/g, "");

    return name.match(matcher) !== null;
  }, []);

  const onChange = useCallback(
    (selectedIds: Set<string>) => {
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return;
      navigate({
        to: `/playlists/${playlist.id}`,
        params: { playlistId: playlist.id },
      });
    },
    [listItems, navigate],
  );

  const onDelete = useCallback(
    async (selectedIds: Set<string>) => {
      if (selectedIds.size !== 1) return;
      const playlistId = Array.from(selectedIds)[0];

      const allowed = await promptConfirm({
        danger: true,
        message: i18next.t("player.confirmDeletePlaylist", {
          defaultValue: "This will permanently delete this playlist",
        }),
        confirmMessage: i18next.t("playlist.confirmDelete.ok", {
          defaultValue: "OK",
        }),
        cancelMessage: i18next.t("playlist.confirmDelete.cancel", {
          defaultValue: "Cancel",
        }),
      });
      if (!allowed) return;

      const response = await playlistApi.deletePlaylist(playlistId);
      if (!response.ok) return;
      // TODO: Maybe could be optimistic? But then need to take all
      // children into account too if deleting from repo.
      await sync.startSync();

      // After deleting the current item no long exists so we can navigate
      // away from it.
      navigate({
        to: `/playlists`,
      });
    },
    [promptConfirm, navigate],
  );

  const onContextMenu = useCallback(
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
          await onDelete(new Set([playlist.id]));
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
    [listItems, userConfirmQueueReplace, populateUpNext, onDelete, openFolders],
  );

  const onDoubleClick = useCallback(
    async (playlist: Playlist) => {
      if (playlist.isFolder) {
        if (!openFolders.has(playlist.id)) {
          openFolders.add(playlist.id);
          setOpenFolders(new Set([...openFolders]));
        } else {
          openFolders.delete(playlist.id);
          setOpenFolders(new Set([...openFolders]));
        }
      }

      if (!(await userConfirmQueueReplace())) return;
      populateUpNext({ playlistId: playlist.id });
    },
    [userConfirmQueueReplace, openFolders, populateUpNext],
  );

  const onSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;
      const playlist = listItems.find((playlist) =>
        selectedIds.has(playlist.id),
      );
      if (!playlist) return;
      populateUpNext({ playlistId: playlist.id });
    },
    [listItems, userConfirmQueueReplace, populateUpNext],
  );

  const renderItem = useCallback(
    (playlist: ListItem, state: ListItemState) => (
      <PlaylistListItem isSelected={state.isSelected} playlist={playlist} />
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
      onTypeMatch={onTypeMatch}
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
      onContextMenu={onContextMenu}
      onChange={onChange}
      onDelete={onDelete}
      onSubmit={onSubmit}
      onDoubleClick={onDoubleClick}
      renderItem={renderItem}
    />
  );
}
