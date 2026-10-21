import { createFileRoute, Navigate } from "@tanstack/react-router";
import { EmptyView } from "../../components/EmptyView";
import { Loading } from "../../components/Loading";
import { Playlist } from "../../components/Playlist";
import i18next from "../../i18next";
import { usePlaylist, usePlaylistItems } from "../../library";
import type { UUID } from "../../types";

export const Route = createFileRoute("/_authenticated/playlists/$playlistId")({
  staticData: { view: "playlists" as const },
  component: PlaylistDetail,
});

type Params = {
  playlistId: UUID;
};

function PlaylistDetail() {
  const { playlistId } = Route.useParams() as Params;
  const { data: playlist, loading } = usePlaylist(playlistId);
  const { data: items, loading: loadingItems } = usePlaylistItems(playlistId);

  if (loading || loadingItems) {
    return <Loading />;
  }

  if (!playlist) {
    return <Navigate to="/playlists" />;
  }

  if (playlist.isFolder) {
    return (
      <div className="relative h-full mx-4 lg:mx-8">
        <header className="mt-18 md:mt-4 lg:mt-5">
          <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
            {playlist.name}
          </h1>
          <span className="text-sm text-page-fg-muted">
            {i18next.t("playlist.folder", { defaultValue: "Folder" })}
          </span>
        </header>

        <div className="absolute top-0 left-0 right-0 bottom-0 pointer-events-none">
          <EmptyView
            message={i18next.t("emptyView.selectPlaylist", {
              defaultValue: "Select a playlist",
            })}
          />
        </div>
      </div>
    );
  }

  const playlistItems = items.filter((item) => item.playlistId === playlist.id);

  return (
    <div className="relative h-full mx-4 lg:mx-8">
      <Playlist playlist={playlist} items={playlistItems} />

      {playlistItems.length === 0 && playlist.trackCount === 0 && (
        <div className="absolute top-0 left-0 right-0 bottom-0 pointer-events-none">
          <EmptyView
            message={i18next.t("playlist.emptyPlaylist", {
              defaultValue: "There are no tracks in this playlist yet.",
            })}
          />
        </div>
      )}
    </div>
  );
}
