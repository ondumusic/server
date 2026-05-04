import { createFileRoute, Outlet } from "@tanstack/react-router";
import { Panel } from "../../components/Panel";

export const Route = createFileRoute("/_authenticated/albums")({
  staticData: { view: "albums" as const },
  component: Albums,
});

function Albums() {
  return (
    <Panel>
      Albums: Coming Soon
      <Outlet />
    </Panel>
  );
}
