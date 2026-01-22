import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  beforeLoad: async () => {
    // For now index just redirects to artists
    throw redirect({
      to: "/artists",
      replace: true,
    });
  },
  component: () => <div />,
});
