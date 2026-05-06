import type { PropsWithChildren, ReactNode } from "react";
import {
  Group,
  Panel as ResizablePanel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { useMediaQuery } from "../hooks/useMediaQuery";
import { ToastProvider } from "../hooks/useToast";
import { classNames } from "../utils/classNames";

export function Panel({
  children,
  renderSidebar,
  mobileShowSidebar,
  size = "large",
}: PropsWithChildren<{
  size?: "small" | "large";
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

  return (
    <div
      className={classNames([
        "relative flex flex-col mx-auto overflow-hidden text-panel-fg",
        "border border-panel-border",
        size === "large" && "h-full w-full lg:shadow-lg lg:rounded-md",
        size === "small" &&
          "max-w-md p-6 backdrop-blur-2xl backdrop-saturate-150 bg-panel-bg shadow-lg rounded-md",
      ])}
    >
      {allowPanels ? (
        <Group
          className="w-full"
          defaultLayout={defaultLayout}
          onLayoutChange={handleLayoutChange}
          orientation="horizontal"
        >
          <ResizablePanel
            id="left"
            defaultSize="30%"
            minSize="17%"
            maxSize="40%"
          >
            <div
              role="none"
              className={classNames([
                "h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
                "bg-sidebar-bg backdrop-blur-2xl backdrop-saturate-150",
              ])}
            >
              {renderSidebar()}
            </div>
          </ResizablePanel>
          <Separator className="w-[1px] bg-sidebar-divider [&[data-separator='hover']]:bg-sidebar-divider-hover [&[data-separator='active']]:bg-sidebar-divider-active focus:outline-none focus:bg-sidebar-divider-active" />
          <ResizablePanel id="right" minSize="60%">
            <ToastProvider>
              <div className="@container h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden bg-panel-bg backdrop-blur-2xl backdrop-saturate-150">
                {children}
              </div>
            </ToastProvider>
          </ResizablePanel>
        </Group>
      ) : (
        <div className="@container w-full h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden bg-panel-bg backdrop-blur-2xl backdrop-saturate-150">
          {mobileShowSidebar && hasSidebar ? renderSidebar() : children}
        </div>
      )}
    </div>
  );
}
