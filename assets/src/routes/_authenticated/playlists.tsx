import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/playlists")({
  staticData: { view: "playlists" as const },
  component: Playlists,
});

function Playlists() {
  return (
    <div className="w-full h-full bg-panel-bg backdrop-blur-2xl backdrop-saturate-150">
      Playlists: Coming Soon
      <Outlet />
    </div>
  );
}
