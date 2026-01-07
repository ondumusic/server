import {
  Group,
  Panel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { Outlet } from "react-router";
import { ArtistListView } from "../views/ArtistListView";

export function ArtistsLayout() {
  const { defaultLayout, onLayoutChange } = useDefaultLayout({
    groupId: "artistPage",
    storage: localStorage,
  });

  return (
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
      <Separator className="w-[2px] bg-accent-200 [&[data-separator='hover']]:bg-accent-300 [&[data-separator='active']]:bg-accent-300" />
      <Panel id="right" minSize="60%">
        <div className="h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <Outlet />
        </div>
      </Panel>
    </Group>
  );
}
