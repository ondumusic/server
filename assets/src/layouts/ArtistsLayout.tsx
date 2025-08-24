import { Panel, PanelGroup, PanelResizeHandle } from "react-resizable-panels";
import { Outlet } from "react-router";
import { ArtistListView } from "../views/ArtistListView";

export function ArtistsLayout() {
  return (
    <PanelGroup autoSaveId="artistPage" direction="horizontal">
      <Panel defaultSize={30} minSize={17} maxSize={80}>
        <div className="overflow-y-auto h-full bg-stone-100">
          <ArtistListView />
        </div>
      </Panel>
      <PanelResizeHandle className="w-1 bg-white border-l border-stone-200" />
      <Panel minSize={30}>
        <div className="overflow-y-auto h-full p-4 bg-white">
          <Outlet />
        </div>
      </Panel>
    </PanelGroup>
  );
}
