import {
  useLocation,
  useMatches,
  useNavigate,
  useRouter,
} from "@tanstack/react-router";
import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import { classNames } from "../utils/classNames";

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

type Rect = { x: number; width: number };

// Remember last routes (e.g. if you switch between artist view to album view
// it would be nice to preserve the params like current artist)
const lastVisited = new Map<ViewId, string>();

export function NavBar() {
  const location = useLocation();
  const navigate = useNavigate();
  const matches = useMatches();
  const router = useRouter();

  const active =
    matches
      .map((m) => m.staticData?.view)
      .filter((v): v is ViewId => Boolean(v))
      .pop() ?? "artists";

  const [hovered, setHovered] = useState<ViewId | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const [activeRect, setActiveRect] = useState<Rect | null>(null);
  const [hoverRect, setHoverRect] = useState<Rect | null>(null);
  const [enableTransition, setEnableTransition] = useState(false);

  const measure = useCallback((id: ViewId): Rect | null => {
    const el = itemRefs.current[id];
    const container = containerRef.current;
    if (!el || !container) return null;
    const cr = container.getBoundingClientRect();
    const er = el.getBoundingClientRect();
    return { x: er.left - cr.left, width: er.width };
  }, []);

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

  // Set the rects at the right place
  useLayoutEffect(() => {
    const rect = measure(active);
    if (rect) setActiveRect(rect);

    const container = containerRef.current;
    if (!container) return;
    const observer = new ResizeObserver(() => {
      const r = measure(active);
      if (r) setActiveRect(r);
      if (hovered) {
        const h = measure(hovered);
        if (h) setHoverRect(h);
      }
    });
    observer.observe(container);
    return () => observer.disconnect();
  }, [active, hovered, measure]);

  useLayoutEffect(() => {
    if (!hovered) {
      setHoverRect(null);
      return;
    }
    const rect = measure(hovered);
    if (rect) setHoverRect(rect);
  }, [hovered, measure]);

  // After the indicator has painted at its initial position, enable
  // transitions so subsequent changes animate.
  useEffect(() => {
    if (activeRect && !enableTransition) {
      setEnableTransition(true);
    }
  }, [activeRect, enableTransition]);

  return (
    <div
      ref={containerRef}
      role="tablist"
      onMouseLeave={() => setHovered(null)}
      className={classNames([
        "relative bg-navbar-bg mb-5 flex lg:shadow-md lg:rounded-lg items-end",
        "text-navbar-fg text-sm",
        "backdrop-blur-2xl backdrop-saturate-150 px-1 py-1 gap-0.5",
      ])}
    >
      <div
        aria-hidden
        className="pointer-events-none absolute top-1 bottom-1 rounded-lg bg-navbar-hover-bg transition-opacity duration-200"
        style={{
          transform: `translateX(${(hoverRect?.x ?? 0) - 4}px)`,
          width: hoverRect?.width ?? 0,
          opacity: hoverRect && hovered !== active ? 1 : 0,
        }}
      />

      {activeRect && (
        <div
          aria-hidden
          className="pointer-events-none absolute top-1 bottom-1 rounded-lg bg-navbar-active-bg shadow-[0_1px_3px_rgba(0,0,0,0.06)]"
          style={{
            transform: `translateX(${activeRect.x - 4}px)`,
            width: activeRect.width,
            transition: enableTransition
              ? "transform 250ms cubic-bezier(0.4,0,0.2,1), width 250ms cubic-bezier(0.4,0,0.2,1)"
              : "none",
          }}
        />
      )}

      {items.map((item) => {
        const isActive = active === item.id;

        // Use last visited href, unless we are already there then go to the
        // original item.href (e.g. to go from detail view to overview)
        let targetHref = lastVisited.get(item.id) ?? item.href;
        if (targetHref === location.href) targetHref = item.href;

        return (
          <button
            type="button"
            role="tab"
            aria-selected={isActive}
            key={item.id}
            ref={(el) => {
              itemRefs.current[item.id] = el;
            }}
            onClick={() => navigate({ to: targetHref })}
            onMouseEnter={() => setHovered(item.id)}
            className="relative z-10 rounded-md px-4 py-1.5 text-sm cursor-pointer"
          >
            {item.label}
          </button>
        );
      })}
    </div>
  );
}
