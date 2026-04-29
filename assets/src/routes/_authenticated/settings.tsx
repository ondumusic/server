import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/settings")({
  staticData: { view: "settings" as const },
  component: Settings,
});

function Settings() {
  return (
    <div className="w-full h-full bg-panel-bg backdrop-blur-2xl backdrop-saturate-150">
      Settings: Coming Soon
      <Outlet />
    </div>
  );
}
