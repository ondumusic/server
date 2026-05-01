import { createFileRoute, Outlet } from "@tanstack/react-router";
import { repo } from "../../library";

export const Route = createFileRoute("/_authenticated/settings")({
  staticData: { view: "settings" as const },
  component: Settings,
});

function Settings() {
  return (
    <div className="w-full h-full bg-panel-bg backdrop-blur-2xl backdrop-saturate-150">
      Settings: Coming Soon
      <hr />
      <h3 className="font-bold">debug options</h3>
      <button
        type="button"
        className="border border-red-500 p-1"
        onClick={() => repo.teardown().then(() => location.reload())}
      >
        delete local indexeddb and refresh
      </button>
      <Outlet />
    </div>
  );
}
