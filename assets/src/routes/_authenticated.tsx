import {
  createFileRoute,
  Navigate,
  Outlet,
  redirect,
  useLocation,
} from "@tanstack/react-router";
import { type DragEvent, useEffect, useState } from "react";
import {
  Group,
  Panel as ResizablePanel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { MiniPlayer } from "../components/MiniPlayer";
import { NavBar } from "../components/NavBar";
import { NoticeBanner } from "../components/NoticeBanner";
import { Player } from "../components/Player";
import { SideNav } from "../components/SideNav";
import { useMediaQuery } from "../hooks/useMediaQuery";
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
  const isDesktop = useMediaQuery("(width >= 64rem)");
  const [isPanelOpen, setIsPanelOpen] = useState(
    location.pathname !== "/" || queue.length === 0,
  );
  const [isUpNextOpen, setIsUpNextOpen] = useState(false);
  const { defaultLayout, onLayoutChange: handleLayoutChange } =
    useDefaultLayout({
      groupId: "sideNavSplitView",
      storage: localStorage,
    });

  const isOnboarding = false;

  useEffect(() => {
    if (location.pathname === "/") return;
    setIsPanelOpen(true);
  }, [location]);

  // Large screens always show the panel, so there is nothing to show at "/".
  if (location.pathname === "/" && (isDesktop || queue.length === 0)) {
    return <Navigate to="/artists" replace />;
  }

  // Open Up Next when dragging something onto the player, so it can be
  // dropped there.
  const handleDragOver = (e: DragEvent) => {
    const sourceListId = e.dataTransfer.types
      .find((t) => t.startsWith("application/x-list-"))
      ?.replace("application/x-list-", "");
    if (!sourceListId) return;

    setIsUpNextOpen(true);
  };

  if (isDesktop) {
    return (
      <div className="flex relative h-full overflow-hidden bg-page-bg">
        <NoticeBanner />

        <Group
          className="flex-1 min-w-0"
          defaultLayout={defaultLayout}
          onLayoutChange={handleLayoutChange}
          orientation="horizontal"
        >
          <ResizablePanel
            id="sideNav"
            defaultSize="18rem"
            minSize="14rem"
            maxSize="20rem"
          >
            <div className="h-full py-5 px-3 flex flex-col bg-zinc-200 dark:bg-zinc-950">
              <div className="flex-shrink-0">
                <SideNav />
              </div>
              {/* biome-ignore lint/a11y/noStaticElementInteractions: allow dragging events */}
              <div
                className="flex-1 min-h-0 mt-3 flex flex-col justify-end"
                onDragOver={handleDragOver}
              >
                <MiniPlayer
                  isUpNextOpen={isUpNextOpen}
                  onToggleUpNext={() => setIsUpNextOpen(!isUpNextOpen)}
                />
              </div>
            </div>
          </ResizablePanel>
          <Separator className="w-[1px] bg-black/10 dark:bg-white/10 [&[data-separator='hover']]:bg-black/20 dark:[&[data-separator='hover']]:bg-white/20 [&[data-separator='active']]:bg-sidebar-divider-active focus:outline-none focus:bg-sidebar-divider-active" />
          <ResizablePanel id="main">
            <div className="relative h-full flex flex-col">
              <Outlet />
            </div>
          </ResizablePanel>
        </Group>
      </div>
    );
  }

  return (
    <div className="flex flex-col-reverse lg:flex-row lg:justify-center lg:items-center relative h-full">
      <NoticeBanner />
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
