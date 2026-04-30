import { createFileRoute, Outlet } from "@tanstack/react-router";

import {
  Group,
  Panel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { ArtistList } from "../../components/ArtistList";
import { useMediaQuery } from "../../hooks/useMediaQuery";
import type { UUID } from "../../types";
import { classNames } from "../../utils/classNames";

export const Route = createFileRoute("/_authenticated/artists/{-$artistId}")({
  staticData: { view: "artists" as const },
  component: Artists,
});

type Params = {
  artistId: UUID;
};

function Artists() {
  const allowPanels = useMediaQuery("(width >= 48rem)");
  const { artistId } = Route.useParams() as Params;

  const { defaultLayout, onLayoutChange } = useDefaultLayout({
    groupId: "panelSplitView",
    storage: localStorage,
  });

  return allowPanels ? (
    <Group
      className="w-full"
      defaultLayout={defaultLayout}
      onLayoutChange={onLayoutChange}
      orientation="horizontal"
    >
      <Panel id="left" defaultSize="30%" minSize="17%" maxSize="40%">
        <div
          className={classNames([
            "h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
            "bg-sidebar-bg backdrop-blur-2xl backdrop-saturate-150",
          ])}
        >
          <ArtistList artistId={artistId} />
        </div>
      </Panel>
      <Separator className="w-[1px] bg-sidebar-divider [&[data-separator='hover']]:bg-sidebar-divider-hover [&[data-separator='active']]:bg-sidebar-divider-active focus:outline-none focus:bg-sidebar-divider-active" />
      <Panel id="right" minSize="60%">
        <div className="@container h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden bg-panel-bg backdrop-blur-2xl backdrop-saturate-150">
          <Outlet />
        </div>
      </Panel>
    </Group>
  ) : (
    <div className="@container w-full h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      {artistId ? <Outlet /> : <ArtistList />}
    </div>
  );
}
