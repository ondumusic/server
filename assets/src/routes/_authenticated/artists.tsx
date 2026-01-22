import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/artists")({
  component: Artists,
});

function Artists() {
  return <Outlet />;
}
