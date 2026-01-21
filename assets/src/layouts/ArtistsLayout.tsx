import {
  Group,
  Panel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { Outlet, useParams } from "react-router";
import { useMediaQuery } from "../hooks/useMediaQuery";
import type { UUID } from "../types";
import { ArtistListView } from "../views/ArtistListView";

type Params = {
  artistId?: UUID;
};

export function ArtistsLayout() {
  const allowPanels = useMediaQuery("(width >= 48rem)");
  const { artistId } = useParams() as Params;

  const { defaultLayout, onLayoutChange } = useDefaultLayout({
    groupId: "artistPage",
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
        <div className="h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden bg-accent-50/40">
          <ArtistListView />
        </div>
      </Panel>
      <Separator className="w-[1px] bg-accent-200 [&[data-separator='hover']]:bg-accent-300 [&[data-separator='active']]:bg-accent-300 focus:outline-none focus:bg-accent-400" />
      <Panel id="right" minSize="60%">
        <div className="@container h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <Outlet />
        </div>
      </Panel>
    </Group>
  ) : (
    <div className="@container w-full h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      {artistId ? <Outlet /> : <ArtistListView />}
    </div>
  );
}
