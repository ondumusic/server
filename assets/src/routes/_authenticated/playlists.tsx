import { createFileRoute, Outlet, useParams } from "@tanstack/react-router";
import { useCallback, useEffect } from "react";
import { Panel } from "../../components/Panel";
import { PlaylistList } from "../../components/PlaylistList";
import { usePlaylistPicker } from "../../hooks/usePlaylistPicker";
import type { UUID } from "../../types";

export const Route = createFileRoute("/_authenticated/playlists")({
  staticData: { view: "playlists" as const },
  component: Playlists,
});

type Params = {
  playlistId: UUID;
};

function Playlists() {
  const routeParams = useParams({
    from: "/_authenticated/playlists/$playlistId",
    shouldThrow: false,
  }) as Params;
  const playlistId = routeParams?.playlistId;

  const { showPlaylistPicker } = usePlaylistPicker();

  useEffect(() => {
    showPlaylistPicker().then((playlistId) => {
      console.log(playlistId);
    });
  }, [showPlaylistPicker]);

  const renderSidebar = useCallback(() => {
    return <PlaylistList playlistId={playlistId} />;
  }, [playlistId]);

  return (
    <Panel renderSidebar={renderSidebar} mobileShowSidebar={!playlistId}>
      <Outlet />
    </Panel>
  );
}
