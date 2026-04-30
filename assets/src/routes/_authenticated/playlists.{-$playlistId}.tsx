import { createFileRoute, Outlet } from "@tanstack/react-router";
import {
  Group,
  Panel,
  Separator,
  useDefaultLayout,
} from "react-resizable-panels";
import { PlaylistList } from "../../components/PlaylistList";
import { useContextMenu } from "../../hooks/useContextMenu";
import { useMediaQuery } from "../../hooks/useMediaQuery";
import i18next from "../../i18next";
import type { UUID } from "../../types";
import { classNames } from "../../utils/classNames";

export const Route = createFileRoute(
  "/_authenticated/playlists/{-$playlistId}",
)({
  staticData: { view: "playlists" as const },
  component: Playlists,
});

type Params = {
  playlistId: UUID;
};

function Playlists() {
  const { playlistId } = Route.useParams() as Params;
  const { createContextMenu } = useContextMenu();

  const allowPanels = useMediaQuery("(width >= 48rem)");
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
          role="none"
          className={classNames([
            "h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
            "bg-sidebar-bg backdrop-blur-2xl backdrop-saturate-150",
          ])}
          onContextMenu={createContextMenu<HTMLDivElement>(() => {
            return [
              {
                type: "item",
                key: "create_playlist",
                label: i18next.t("contextMenu.createPlaylist", {
                  defaultValue: "Create Playlist",
                }),
                onClick: async () => {
                  alert("Lets create playlist");
                  // if (!(await userConfirmQueueReplace())) return;
                  // populateUpNext({ playlistId: playlist.id });
                },
              },
              {
                type: "item",
                key: "create_folder",
                label: i18next.t("contextMenu.createPlaylistFolder", {
                  defaultValue: "Create Folder",
                }),
                onClick: async () => {
                  alert("Lets create folder");
                  // if (!(await userConfirmQueueReplace())) return;
                  // populateUpNext({ playlistId: playlist.id });
                },
              },
            ];
          })}
        >
          <PlaylistList playlistId={playlistId} />
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
      {playlistId ? <Outlet /> : <PlaylistList />}
    </div>
  );
}
