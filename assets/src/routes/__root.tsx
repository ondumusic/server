import { createRootRouteWithContext, Outlet } from "@tanstack/react-router";
import type { RouteContext } from "../types";

// Use the routerContext to create your root route
export const Route = createRootRouteWithContext<RouteContext>()({
  component: () => <Outlet />,
});
