import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/artists")({
  staticData: { view: "artists" as const },
  component: Artists,
});

function Artists() {
  return <Outlet />;
}
