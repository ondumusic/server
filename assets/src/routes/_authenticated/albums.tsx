import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/albums")({
  staticData: { view: "albums" as const },
  component: Albums,
});

function Albums() {
  return (
    <div className="w-full h-full bg-panel-bg backdrop-blur-2xl backdrop-saturate-150">
      <Outlet />
    </div>
  );
}
