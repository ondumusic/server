import {
  createFileRoute,
  Outlet,
  useNavigate,
  useParams,
} from "@tanstack/react-router";
import { useCallback } from "react";
import { playlistApi } from "../../api";
import { Playlists } from "../../components/Playlists";
import { SplitView } from "../../components/SplitView";
import { sidebarTitleHeight } from "../../constants/sidebarTitleHeight";
import { useDialog } from "../../hooks/useDialog";
import { usePlayer } from "../../hooks/usePlayer";
import { maybeResetPlaylistPicker } from "../../hooks/usePlaylistPicker";
import i18next from "../../i18next";
import { sync } from "../../library";
import type { Playlist, UUID } from "../../types";

export const Route = createFileRoute("/_authenticated/playlists")({
  staticData: { view: "playlists" as const },
  component: PlaylistsLayout,
});

type Params = {
  playlistId: UUID;
};

function PlaylistsLayout() {
  const navigate = useNavigate();
  const { promptConfirm } = useDialog();
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const routeParams = useParams({
    from: "/_authenticated/playlists/$playlistId",
    shouldThrow: false,
  }) as Params;
  const playlistId = routeParams?.playlistId;

  const handleSubmit = useCallback(
    async (playlist: Playlist) => {
      if (!(await userConfirmQueueReplace())) return;
      populateUpNext({ playlistId: playlist.id });
    },
    [userConfirmQueueReplace, populateUpNext],
  );

  const handleChange = useCallback(
    async (playlist: Playlist) => {
      navigate({
        to: `/playlists/${playlist.id}`,
        params: { playlistId: playlist.id },
      });
    },
    [navigate],
  );

  const handleCreate = useCallback(
    async (playlist: Playlist) => {
      navigate({
        to: `/playlists/${playlist.id}`,
        params: { playlistId: playlist.id },
      });
    },
    [navigate],
  );

  const handleDelete = useCallback(
    async (playlist: Playlist) => {
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

      const response = await playlistApi.deletePlaylist(playlist.id);
      if (!response.ok) return;

      maybeResetPlaylistPicker(playlist.id);

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

  const renderSidebar = useCallback(() => {
    return (
      <Playlists
        playlistId={playlistId}
        paddingTop={sidebarTitleHeight + 10}
        showBottomBar={true}
        onCreate={handleCreate}
        onChange={handleChange}
        onDelete={handleDelete}
        onSubmit={handleSubmit}
      />
    );
  }, [playlistId, handleCreate, handleChange, handleDelete, handleSubmit]);

  return (
    <SplitView
      renderSidebar={renderSidebar}
      mobileShowSidebar={!playlistId}
      sidebarTitle={i18next.t("playlists.title", { defaultValue: "Playlists" })}
    >
      <Outlet />
    </SplitView>
  );
}
