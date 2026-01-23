import {
  createFileRoute,
  Navigate,
  Outlet,
  redirect,
  useLocation,
} from "@tanstack/react-router";
import { useState } from "react";
import { Panel } from "../components/Panel";
import { Player } from "../components/Player";
import { useQueue } from "../hooks/useQueue";
import { auth } from "../services/auth";

export const Route = createFileRoute("/_authenticated")({
  beforeLoad: async ({ context, location }) => {
    if (!context.auth.isLoggedIn) {
      auth.logout();

      throw redirect({
        to: "/login",
        search: { redirect: location.href },
        replace: true,
      });
    }
  },
  component: Authenticated,
});

function Authenticated() {
  const location = useLocation();
  const { queue } = useQueue();
  const [isPanelOpen, setIsPanelOpen] = useState(
    location.pathname !== "/" || queue.length === 0,
  );

  const isOnboarding = false;

  if (location.pathname === "/" && queue.length === 0) {
    return <Navigate to="/artists" replace />;
  }

  return (
    <div className="flex flex-col-reverse lg:flex-row relative h-full">
      <div
        className={
          "flex-shrink-0 lg:absolute lg:w-1/3 xl:w-1/4 h-20 lg:h-full left-0 overflow-hidden lg:py-6 xl:py-8 lg:px-4 xl:py-6" +
          "flex justify-center items-center flex-col " +
          "transition-all duration-400 ease-in-out " +
          (isPanelOpen
            ? " translate-x-0 lg:scale-95"
            : " lg:translate-x-full xl:translate-x-[150%]")
        }
      >
        {!isOnboarding && (
          <Player isPanelOpen={isPanelOpen} setIsPanelOpen={setIsPanelOpen} />
        )}
      </div>

      <div
        className={
          "flex-shrink-1 lg:absolute lg:left-1/3 lg:w-2/3 xl:left-1/4 xl:w-3/4 h-[calc(100%-80px)] lg:h-full lg:p-4 xl:p-6 lg:pl-0 xl:pl-0 " +
          "flex justify-center items-center flex-col " +
          "transition-all duration-400 ease-in-out " +
          (isPanelOpen
            ? " translate-y-0 lg:translate-x-0 opacity-100 scale-100"
            : " -translate-y-full lg:translate-y-0 lg:translate-x-full opacity-0 scale-90")
        }
      >
        <Panel main>
          <Outlet />
        </Panel>
      </div>
    </div>
  );
}
