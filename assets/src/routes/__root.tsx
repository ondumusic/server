import {
  createRootRouteWithContext,
  Outlet,
  redirect,
} from "@tanstack/react-router";
import type { RouteContext } from "../types";

// Use the routerContext to create your root route
export const Route = createRootRouteWithContext<RouteContext>()({
  beforeLoad: async ({ location, context }) => {
    const onboardingRoute = !!location.href.match(/^\/onboarding/);
    const loginRoute =
      context.onboarding.step !== "user" && !!location.href.match(/^\/login/);

    if (!onboardingRoute && !loginRoute && context.onboarding.step) {
      throw redirect({ to: `/onboarding/${context.onboarding.step}` });
    }

    if (onboardingRoute && !context.onboarding.step) {
      throw redirect({ to: "/" });
    }
  },
  component: () => <Outlet />,
});
