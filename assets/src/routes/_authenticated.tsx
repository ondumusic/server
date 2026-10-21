import {
  createFileRoute,
  Navigate,
  Outlet,
  redirect,
  useLocation,
} from "@tanstack/react-router";
import { type DragEvent, useState } from "react";
import { flushSync } from "react-dom";
import {
  Group,
  Panel as ResizablePanel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { FullPlayer } from "../components/FullPlayer";
import { MiniPlayer } from "../components/MiniPlayer";
import { NoticeBanner } from "../components/NoticeBanner";
import { SideNav } from "../components/SideNav";
import { SmallScreen } from "../components/SmallScreen";
import { useMediaQuery } from "../hooks/useMediaQuery";
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
  const isDesktop = useMediaQuery("(width >= 64rem)");
  const [isUpNextOpen, setIsUpNextOpen] = useState(false);
  const [isNowPlayingOpen, setIsNowPlayingOpen] = useState(false);
  const { defaultLayout, onLayoutChange: handleLayoutChange } =
    useDefaultLayout({
      groupId: "sideNavSplitView",
      storage: localStorage,
    });

  // There is nothing to show at "/", start with the artists instead
  if (location.pathname === "/") {
    return <Navigate to="/artists" replace />;
  }

  // This will show/hide the full screen player using a CSS view transition.
  // Using flushSync because the DOM has to be updated inside `startViewTransition`.
  const toggleNowPlaying = (open: boolean) => {
    if (!document.startViewTransition) {
      setIsNowPlayingOpen(open);
      return;
    }

    document.startViewTransition(() => {
      flushSync(() => setIsNowPlayingOpen(open));
    });
  };

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
      <div className="flex relative h-full overflow-hidden bg-page-bg transition-opacity duration-400 starting:opacity-0">
        <Group
          inert={isNowPlayingOpen}
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
            groupResizeBehavior="preserve-pixel-size"
            style={{ overflow: "hidden" }}
          >
            <div className="h-full py-5 px-3 flex flex-col bg-sidenav-bg">
              <div className="flex-shrink-0">
                <SideNav />
              </div>
              <NoticeBanner className="flex-shrink-0 mt-3" />
              {/* biome-ignore lint/a11y/noStaticElementInteractions: allow dragging events */}
              <div
                className="flex-1 min-h-0 mt-3 flex flex-col justify-end"
                onDragOver={handleDragOver}
              >
                <MiniPlayer
                  isUpNextOpen={isUpNextOpen}
                  onToggleUpNext={() => setIsUpNextOpen(!isUpNextOpen)}
                  isNowPlayingOpen={isNowPlayingOpen}
                  onNowPlayingOpen={() => toggleNowPlaying(true)}
                />
              </div>
            </div>
          </ResizablePanel>
          <Separator className="w-[1px] bg-black/10 dark:bg-white/10 [&[data-separator='hover']]:bg-black/20 dark:[&[data-separator='hover']]:bg-white/20 [&[data-separator='active']]:bg-sidebar-divider-active focus:outline-none focus:bg-sidebar-divider-active" />
          <ResizablePanel id="main" style={{ overflow: "hidden" }}>
            <div className="relative h-full flex flex-col">
              <Outlet />
            </div>
          </ResizablePanel>
        </Group>

        {isNowPlayingOpen && (
          <FullPlayer onClose={() => toggleNowPlaying(false)} />
        )}
      </div>
    );
  }

  return <SmallScreen />;
}
