import {
  createFileRoute,
  Outlet,
  useMatchRoute,
  useNavigate,
} from "@tanstack/react-router";
import { useState } from "react";
import { infoApi, scanApi } from "../../api";
import { SpinnerIcon } from "../../components/icons/SpinnerIcon";
import { Marquee } from "../../components/Marquee";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { SplitView } from "../../components/SplitView";
import { sidebarTitleHeight } from "../../constants/sidebarTitleHeight";
import { usePhoenixSocket } from "../../hooks/usePhoenixSocket";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import { classNames } from "../../utils/classNames";

export const Route = createFileRoute("/_authenticated/settings")({
  loader: () => infoApi.getInfo(),
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

interface ListItem {
  id: string;
  type?: "header";
  selectable?: boolean;
  label: string;
  current?: boolean;
}

function SettingsLayout() {
  const matchRoute = useMatchRoute();
  const navigate = useNavigate();
  const { showToast } = useToast();
  const { waitForScan } = usePhoenixSocket();
  const [isScanning, setIsScanning] = useState(false);
  const serverInfo = Route.useLoaderData();

  // Settings stored on the server first, then the ones for this browser only.
  const settingSections: ListItem[] = [
    {
      id: "server",
      type: "header",
      selectable: false,
      label: i18next.t("settings.sections.server", {
        defaultValue: "Server",
      }),
    },
    {
      id: "account",
      current: matchRoute({ to: "/settings/account/" }) !== false,
      label: i18next.t("settings.account.title", {
        defaultValue: "Account",
      }),
    },
    {
      id: "library",
      current: matchRoute({ to: "/settings/library/" }) !== false,
      label: i18next.t("settings.library.title", {
        defaultValue: "Library",
      }),
    },
    {
      id: "issues",
      current: matchRoute({ to: "/settings/issues/" }) !== false,
      label: i18next.t("settings.issues.title", {
        defaultValue: "Issues",
      }),
    },
    {
      id: "browser",
      type: "header",
      selectable: false,
      label: i18next.t("settings.sections.browser", {
        defaultValue: "This Browser",
      }),
    },
    {
      id: "appearance",
      current: matchRoute({ to: "/settings/appearance/" }) !== false,
      label: i18next.t("settings.appearance.title", {
        defaultValue: "Appearance",
      }),
    },
    {
      id: "playback",
      current: matchRoute({ to: "/settings/playback/" }) !== false,
      label: i18next.t("settings.playback.title", {
        defaultValue: "Playback",
      }),
    },
    {
      id: "storage",
      current: matchRoute({ to: "/settings/storage/" }) !== false,
      label: i18next.t("settings.storage.title", {
        defaultValue: "Storage",
      }),
    },
  ];

  const renderItem = (item: ListItem, state: ListItemState) => {
    if (item.type === "header") {
      return (
        <div
          className={classNames([
            "px-6 pb-0.5 text-xs font-semibold text-page-fg-muted",
            item.id === "server" ? "pt-5" : "pt-4",
          ])}
        >
          {item.label}
        </div>
      );
    }

    return (
      <li
        className={classNames([
          "mx-3 px-3 rounded-md whitespace-nowrap items-center flex gap-2",
          "text-sm",
          state.isSelected &&
            "bg-sidebar-inactive-bg text-sidebar-inactive-fg [.selectable-list:focus_&]:bg-sidebar-active-bg [.selectable-list:focus_&]:shadow-sm [.selectable-list:focus_&]:text-sidebar-active-fg",
        ])}
      >
        <Marquee className="py-1.5" delay={500} text={item.label} />
        {isScanning && item.id === "library" && (
          <SpinnerIcon className="animate-spin size-5" title={item.label} />
        )}
      </li>
    );
  };

  const handleChange = async (itemIds: Set<string>) => {
    const item = settingSections.find((item) => itemIds.has(item.id));
    if (!item) return;

    navigate({ to: `/settings/${item.id}` });
  };

  const handleContextMenu = (itemIds: Set<string>) => {
    if (itemIds.size !== 1) return [];
    const [id] = itemIds;

    if (id === "library") {
      return [
        {
          type: "item",
          key: "play",
          label: i18next.t("contextMenu.scanLibrary", {
            defaultValue: "Scan the library",
          }),
          onClick: async () => {
            showToast({
              message: i18next.t("toast.startedLibraryScan", {
                defaultValue: "Started scanning the library for new tracks",
              }),
            });

            scanApi.startScanner().then(() => {
              setIsScanning(true);

              waitForScan(() => {
                setIsScanning(false);
                showToast({
                  message: i18next.t("toast.completedLibraryScan", {
                    defaultValue: "Library scan completed",
                  }),
                });
              });
            });
          },
        },
      ];
    }

    return [];
  };

  const currentSection = settingSections.find(
    (section) => section.current === true,
  );

  const renderSidebar = () => (
    <div className="flex flex-col h-full">
      <div className="h-full overflow-auto">
        <SelectableList<ListItem>
          multiple={false}
          items={settingSections}
          renderItem={renderItem}
          selectedIds={new Set(currentSection ? [currentSection.id] : [])}
          defaultFocusId={currentSection?.id}
          paddingTop={sidebarTitleHeight}
          onChange={handleChange}
          onContextMenu={handleContextMenu}
        />
      </div>
      <div className="px-6 py-3 text-xs text-center text-page-fg-muted select-none">
        {i18next.t("settings.serverVersion", {
          defaultValue: "Ondu {{ version }}",
          version: serverInfo.version,
        })}
      </div>
    </div>
  );

  return (
    <SplitView
      renderSidebar={renderSidebar}
      sidebarTitle={i18next.t("settings.title", { defaultValue: "Settings" })}
    >
      <Outlet />
    </SplitView>
  );
}
