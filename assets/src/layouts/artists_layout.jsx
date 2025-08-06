import { Panel, PanelGroup, PanelResizeHandle } from "react-resizable-panels";
import { Outlet } from "react-router";
import { ArtistListView } from "../views/artist_list";

export function ArtistsLayout() {
  return (
    <PanelGroup autoSaveId="artistPage" direction="horizontal">
      <Panel defaultSize={20} minSize={15} maxSize={30}>
        <div className="overflow-y-auto h-full p-4 bg-stone-100">
          <ArtistListView />
        </div>
      </Panel>
      <PanelResizeHandle className="w-[1px] bg-stone-200" />
      <Panel minSize={30}>
        <div className="overflow-y-auto h-full p-4">
          <Outlet />
        </div>
      </Panel>
    </PanelGroup>
  );
}
