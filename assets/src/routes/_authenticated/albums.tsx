import { createFileRoute, Outlet } from "@tanstack/react-router";
import { Panel } from "../../components/Panel";

export const Route = createFileRoute("/_authenticated/albums")({
  staticData: { view: "albums" as const },
  component: AlbumsLayout,
});

function AlbumsLayout() {
  return (
    <Panel>
      Albums: Coming Soon
      <Outlet />
    </Panel>
  );
}
