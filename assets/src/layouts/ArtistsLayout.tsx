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
      defaultLayout={defaultLayout}
      onLayoutChange={onLayoutChange}
      orientation="horizontal"
    >
      <Panel id="left" defaultSize="30%" minSize="17%" maxSize="80%">
        <div className="overflow-y-auto h-screen bg-accent-50 transition-colors">
          <ArtistListView />
        </div>
      </Panel>
      <Separator className="w-1 bg-white border-l border-accent-200" />
      <Panel id="right" minSize="30%">
        <div className="overflow-y-auto h-screen p-4 bg-white">
          <Outlet />
        </div>
      </Panel>
    </Group>
  );
}
