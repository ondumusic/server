import {
  createFileRoute,
  Navigate,
  Outlet,
  useMatchRoute,
  useNavigate,
} from "@tanstack/react-router";
import { useState } from "react";
import { Trans } from "react-i18next";
import { scanApi } from "../../api";
import { LogoutIcon } from "../../components/icons/LogoutIcon";
import { SpinnerIcon } from "../../components/icons/SpinnerIcon";
import { Marquee } from "../../components/Marquee";
import { Panel } from "../../components/Panel";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { sidebarTitleHeight } from "../../constants/sidebarTitleHeight";
import { useAuth } from "../../hooks/useAuth";
import { useDialog } from "../../hooks/useDialog";
import { usePhoenixSocket } from "../../hooks/usePhoenixSocket";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import { classNames } from "../../utils/classNames";

export const Route = createFileRoute("/_authenticated/settings")({
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

interface ListItem {
  id: string;
  label: string;
  current: boolean;
}

function SettingsLayout() {
  const { currentUser, logout } = useAuth();
  const { promptConfirm } = useDialog();
  const { showToast } = useToast();
  const matchRoute = useMatchRoute();
  const navigate = useNavigate();
  const { waitForScan } = usePhoenixSocket();
  const [isScanning, setIsScanning] = useState(false);

  const settingSections = [
    {
      id: "general",
      current: matchRoute({ to: "/settings/" }) !== false,
      label: i18next.t("settings.general.title", {
        defaultValue: "General",
      }),
    },
    {
      id: "security",
      current: matchRoute({ to: "/settings/security/" }) !== false,
      label: i18next.t("settings.security.title", {
        defaultValue: "Security",
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
  ];

  const renderItem = (item: ListItem, state: ListItemState) => (
    <li
      className={classNames([
        "mx-2 px-4 rounded-md whitespace-nowrap items-center flex gap-2",
        "text-sm",
        state.isSelected &&
          "bg-sidebar-inactive-bg text-sidebar-inactive-fg [.selectable-list:focus_&]:bg-sidebar-active-bg [.selectable-list:focus_&]:shadow-sm [.selectable-list:focus_&]:text-sidebar-active-fg",
      ])}
    >
      <Marquee className="py-2.5" delay={500} text={item.label} />
      {isScanning && item.id === "library" && (
        <SpinnerIcon className="animate-spin size-5" title={item.label} />
      )}
    </li>
  );

  const handleChange = async (itemIds: Set<string>) => {
    const item = settingSections.find((item) => itemIds.has(item.id));
    if (!item) return;

    const href = item.id === "general" ? "/settings" : `/settings/${item.id}`;
    navigate({
      to: href,
    });
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

  const handleLogout = async () => {
    const confirmed = await promptConfirm({
      message: i18next.t("promptLogout.message", {
        defaultValue: "Are you sure you want to logout?",
      }),
      confirmMessage: i18next.t("promptLogout.confirm", {
        defaultValue: "Logout",
      }),
      cancelMessage: i18next.t("promptLogout.cancel", {
        defaultValue: "Cancel",
      }),
    });
    if (!confirmed) return;
    logout();
  };

  const currentSection = settingSections.find(
    (section) => section.current === true,
  );

  const renderSidebar = () => {
    return (
      <div className="flex flex-col h-full">
        <div className="h-full overflow-auto">
          <SelectableList<ListItem>
            multiple={false}
            items={settingSections}
            renderItem={renderItem}
            selectedIds={new Set([currentSection?.id ?? "general"])}
            paddingTop={sidebarTitleHeight + 10}
            onChange={handleChange}
            onContextMenu={handleContextMenu}
          />
        </div>
        <div className="mx-2 py-2 border-t border-sidebar-divider">
          <button
            type="button"
            onClick={handleLogout}
            className="flex items-center cursor-pointer gap-4 w-full rounded-md py-1.5 px-2 justify-between text-sm text-page-fg-muted hover:text-page-fg"
          >
            <span className="truncate">
              <Trans
                i18nKey="settings.general.currentlyLoggedIn"
                values={{ username: currentUser?.username }}
                components={{ strong: <strong /> }}
              >
                Logged in as <strong>{"{{username}}"}</strong>
              </Trans>
            </span>

            <LogoutIcon
              className="size-5 flex-shrink-0"
              title={i18next.t("settings.general.logout", {
                defaultValue: "Logout",
              })}
            />
          </button>
        </div>
      </div>
    );
  };

  if (!currentSection) return <Navigate to="/settings" replace />;

  return (
    <Panel
      renderSidebar={renderSidebar}
      sidebarTitle={i18next.t("settings.title", { defaultValue: "Settings" })}
    >
      <Outlet />
    </Panel>
  );
}
