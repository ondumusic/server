import {
  createFileRoute,
  Navigate,
  Outlet,
  redirect,
  useLocation,
} from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { NavBar } from "../components/NavBar";
import { Player } from "../components/Player";
import { useQueue } from "../hooks/useQueue";
import { auth } from "../services/auth";
import { classNames } from "../utils/classNames";

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

  useEffect(() => {
    if (location.pathname === "/") return;
    setIsPanelOpen(true);
  }, [location]);

  if (location.pathname === "/" && queue.length === 0) {
    return <Navigate to="/artists" replace />;
  }

  return (
    <div className="flex flex-col-reverse lg:flex-row lg:justify-center lg:items-center relative h-full">
      <div
        className={classNames([
          "flex-shrink-0 relative lg:w-84 h-20 lg:h-full left-0 overflow-hidden lg:py-6 xl:py-8 lg:px-4 xl:py-6",
          "flex justify-center items-center flex-col",
          "transition-all duration-300 ease-in-out",
          "will-change-[width]",
          isPanelOpen
            ? "translate-x-0 lg:scale-95"
            : "lg:translate-x-[calc(50lvw-50%)] 2xl:translate-x-150",
        ])}
      >
        {!isOnboarding && (
          <Player isPanelOpen={isPanelOpen} setIsPanelOpen={setIsPanelOpen} />
        )}
      </div>

      <div
        className={classNames([
          "flex-shrink-1 relative lg:w-[calc(100%-336px)] 2xl:w-300 max-h-240 h-[calc(100%-80px)] lg:h-full lg:p-4 xl:p-6 xl:py-6 lg:pl-0 xl:pl-0",
          "flex justify-center items-center flex-col",
          "transition-all duration-300 ease-in-out",
          "will-change-[left]",
          isPanelOpen
            ? "translate-y-0 lg:translate-x-0 opacity-100 scale-100"
            : "-translate-y-full lg:translate-y-0 lg:translate-x-full opacity-0 scale-90",
        ])}
      >
        <NavBar />
        <Outlet />
      </div>
    </div>
  );
}
