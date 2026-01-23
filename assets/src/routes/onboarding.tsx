import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/onboarding")({
  component: Onboarding,
});

function Onboarding() {
  return <Outlet />;
}
