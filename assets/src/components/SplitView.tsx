import { type PropsWithChildren, type ReactNode, useMemo } from "react";
import {
  Group,
  Panel as ResizablePanel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { sidebarTitleHeight } from "../constants/sidebarTitleHeight";
import { useMediaQuery } from "../hooks/useMediaQuery";
import { ToastProvider } from "../hooks/useToast";

export function SplitView({
  children,
  renderSidebar,
  mobileShowSidebar,
  sidebarTitle,
}: PropsWithChildren<{
  sidebarTitle?: string;
  renderSidebar?: () => ReactNode;
  mobileShowSidebar?: boolean;
}>) {
  const hasSidebar = typeof renderSidebar === "function";
  const allowPanels = useMediaQuery("(width >= 48rem)") && hasSidebar;
  const { defaultLayout, onLayoutChange: handleLayoutChange } =
    useDefaultLayout({
      groupId: "panelSplitView",
      storage: localStorage,
    });

  const renderedSidebar = useMemo(() => {
    if (!hasSidebar) return;
    return renderSidebar();
  }, [hasSidebar, renderSidebar]);

  return (
    <ToastProvider>
      <div className="relative flex flex-col h-full w-full overflow-hidden text-page-fg">
        {allowPanels && renderedSidebar ? (
          <Group
            className="w-full"
            defaultLayout={defaultLayout}
            onLayoutChange={handleLayoutChange}
            orientation="horizontal"
          >
            <ResizablePanel
              id="left"
              defaultSize="20rem"
              minSize="14rem"
              maxSize="28rem"
              groupResizeBehavior="preserve-pixel-size"
              style={{ overflow: "hidden" }}
            >
              <div
                role="none"
                className="relative h-full flex flex-col overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden bg-sidebar-bg"
              >
                {sidebarTitle && (
                  <div
                    style={{ height: sidebarTitleHeight }}
                    className="absolute z-10 top-0 inset-x-0 flex items-end px-6 pb-2 text-xl font-bold text-page-fg select-none bg-sidebar-bg/70 backdrop-blur-sm border-b border-sidebar-divider"
                  >
                    {sidebarTitle}
                  </div>
                )}
                <div className="flex-1 min-h-0">{renderedSidebar}</div>
              </div>
            </ResizablePanel>
            <Separator className="w-[1px] bg-sidebar-divider [&[data-separator='hover']]:bg-sidebar-divider-hover [&[data-separator='active']]:bg-sidebar-divider-active focus:outline-none focus:bg-sidebar-divider-active" />
            <ResizablePanel
              id="right"
              minSize="60%"
              style={{ overflow: "hidden" }}
            >
              <div className="@container h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden bg-content-bg">
                {children}
              </div>
            </ResizablePanel>
          </Group>
        ) : (
          <div className="@container w-full h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden bg-content-bg">
            {mobileShowSidebar && hasSidebar && renderedSidebar
              ? renderedSidebar
              : children}
          </div>
        )}
      </div>
    </ToastProvider>
  );
}
