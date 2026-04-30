import { createFileRoute, Navigate } from "@tanstack/react-router";
import type { UUID } from "../../types";
// import { classNames } from "../../utils/classNames";

export const Route = createFileRoute("/_authenticated/playlists/$playlistId")({
  staticData: { view: "playlists" as const },
  component: PlaylistsDetail,
});

type Params = {
  playlistId: UUID;
};

function PlaylistsDetail() {
  const { playlistId } = Route.useParams() as Params;

  if (playlistId === "asd") {
    return <Navigate to="/playlists" />;
  }

  return <div>test</div>;
}
