import {
  useLocation,
  useMatches,
  useNavigate,
  useRouter,
} from "@tanstack/react-router";
import { type ReactNode, useCallback, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { classNames } from "../utils/classNames";
import { AlbumIcon } from "./icons/AlbumIcon";
import { MicrophoneIcon } from "./icons/MicrophoneIcon";
import { PlaylistIcon } from "./icons/PlaylistIcon";
import { SettingsIcon } from "./icons/SettingsIcon";
import { SearchField } from "./SearchField";
import { type ListItemState, SelectableList } from "./SelectableList";

type ViewId = "artists" | "albums" | "playlists" | "settings" | "search";

declare module "@tanstack/react-router" {
  interface StaticDataRouteOption {
    view?: ViewId;
  }
}

type NavItem = { id: ViewId; href: string; label: string };

const items: NavItem[] = [
  { id: "artists", href: "/artists", label: "Artists" },
  { id: "albums", href: "/albums", label: "Albums" },
  { id: "playlists", href: "/playlists", label: "Playlists" },
  { id: "settings", href: "/settings", label: "Settings" },
];

// Remember last routes (e.g. if you switch between artist view to album view
// it would be nice to preserve the params like current artist)
const lastVisited = new Map<ViewId, string>();

const icons: Partial<Record<ViewId, ReactNode>> = {
  artists: <MicrophoneIcon className="size-5" title="" strokeWidth={2} />,
  albums: <AlbumIcon className="size-5" title="" strokeWidth={2} />,
  playlists: <PlaylistIcon className="size-5" title="" strokeWidth={2} />,
  settings: <SettingsIcon className="size-5" title="" strokeWidth={2} />,
};

export function SideNav() {
  const { t } = useTranslation();
  const location = useLocation();
  const navigate = useNavigate();
  const matches = useMatches();
  const router = useRouter();

  const active =
    matches
      .map((m) => m.staticData?.view)
      .filter((v): v is ViewId => Boolean(v))
      .pop() ?? "artists";

  // Subscribe to router events to keep lastVisited map up to date.
  useEffect(() => {
    return router.subscribe("onResolved", ({ toLocation }) => {
      const match = router.state.matches
        .map((m) => m.staticData?.view)
        .filter((v): v is ViewId => Boolean(v))
        .pop();

      if (match) {
        lastVisited.set(match, toLocation.pathname + toLocation.searchStr);
      }
    });
  }, [router]);

  const handleChange = useCallback(
    (selectedIds: Set<string>) => {
      const item = items.find((item) => selectedIds.has(item.id));
      if (!item) return;

      // Use last visited href, unless we are already there then go to the
      // original item.href (e.g. to go from detail view to overview)
      let targetHref = lastVisited.get(item.id) ?? item.href;
      if (targetHref === location.href) targetHref = item.href;
      navigate({ to: targetHref });
    },
    [location, navigate],
  );

  const renderItem = useCallback(
    (item: NavItem, state: ListItemState) => (
      <div className="pb-0.5">
        <div
          className={classNames([
            "flex items-center gap-2.5 text-sm px-3 py-1.5 rounded-md cursor-pointer text-page-fg",
            state.isSelected &&
              "font-semibold bg-accent-500 text-white shadow-sm",
          ])}
        >
          <span
            className={classNames([
              "flex-shrink-0",
              state.isSelected ? "text-white" : "text-page-fg-muted",
            ])}
          >
            {icons[item.id]}
          </span>
          <span className="truncate">{item.label}</span>
        </div>
      </div>
    ),
    [],
  );

  return (
    <nav className="flex flex-col h-full">
      <div className="pb-5">
        <SearchField />
      </div>
      <div className="px-3 pb-1.5 text-xs font-semibold text-page-fg-muted select-none">
        {t("sideNav.library", { defaultValue: "Library" })}
      </div>
      <div className="flex-1 min-h-0">
        <SelectableList<NavItem>
          multiple={false}
          items={items}
          selectedIds={new Set([active])}
          defaultFocusId={active}
          onChange={handleChange}
          renderItem={renderItem}
        />
      </div>
    </nav>
  );
}
