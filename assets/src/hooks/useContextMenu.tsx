import {
  createContext,
  type MouseEventHandler,
  type PropsWithChildren,
  type MouseEvent as ReactMouseEvent,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { classNames } from "../utils/classNames";

interface ContextMenuPosition {
  x: number;
  y: number;
}

interface ContextMenuItem {
  key: string;
  label: string;
  onClick(): void;
}

type ContextMenuFunction = () => ContextMenuItem[];
type ContextMenuInput = ContextMenuItem[] | ContextMenuFunction;

interface ContextMenuContextValue {
  createContextMenu<T>(itemsOrFunction: ContextMenuInput): MouseEventHandler<T>;
  closeContextMenu(): void;
}

const ContextMenuContext = createContext<ContextMenuContextValue>({
  createContextMenu: (_itemsOrFunction) => (e) => e,
  closeContextMenu() {},
});

export function useContextMenu() {
  return useContext(ContextMenuContext);
}

export function ContextMenu({
  position,
  items,
  onClose,
}: PropsWithChildren<{
  items: ContextMenuItem[];
  position: ContextMenuPosition;
  onClose(): void;
}>) {
  const menuRef = useRef<HTMLDivElement>(null);
  const [adjustedPosition, setAdjustedPosition] = useState<{
    x: number;
    y: number;
  } | null>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const menu = menuRef.current;
    if (!menu) return;

    // If there is no position we should hide the context menu.
    if (!position) {
      setIsVisible(false);
      return;
    }

    // Calculate the position for the context menu that ideally
    // fits within the viewport bounds.
    const rect = menu.getBoundingClientRect();
    const viewport = {
      width: window.innerWidth,
      height: window.innerHeight,
    };

    let { x, y } = position;

    if (x + rect.width > viewport.width) {
      x = viewport.width - rect.width - 8;
    }
    if (x < 0) x = 8;

    if (y + rect.height > viewport.height) {
      y = viewport.height - rect.height - 8;
    }
    if (y < 0) y = 8;

    // Update the position of the context menu
    setAdjustedPosition({ x, y });

    // In the next animation frame actually make it visible.
    // This is delayed to avoid it being visible in previous
    // coordinates and then popping to the correct ones.
    requestAnimationFrame(() => setIsVisible(true));
  }, [position]);

  useEffect(() => {
    // Close on click outside of context menu
    const handleClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        onClose();
      }
    };

    // Close on Escape button pressed
    // TODO: Maybe need more generic Keyboard handler in the near future.
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      }
    };

    // Close on scroll to avoid it becoming more detached.
    // Alternative would be disabling scroll in all scrollable panes,
    // but I think we should try this first.
    const handleScroll = () => {
      onClose();
    };

    document.addEventListener("mousedown", handleClick);
    document.addEventListener("keydown", handleEscape);
    document.addEventListener("wheel", handleScroll, { passive: true });
    document.addEventListener("scroll", handleScroll, true);

    return () => {
      document.removeEventListener("mousedown", handleClick);
      document.removeEventListener("keydown", handleEscape);
      document.removeEventListener("scroll", handleScroll, true);
      document.removeEventListener("wheel", handleScroll);
    };
  }, [onClose]);

  return (
    <div
      ref={menuRef}
      className={classNames([
        "fixed bg-accent-50 text-selected transition-colors rounded-lg shadow-xl border border-accent-200 py-1 min-w-48 z-50",
        "transition-opacity duration-75",
        isVisible ? "opacity-100" : "opacity-0",
      ])}
      style={{
        left: adjustedPosition ? `${adjustedPosition.x}px` : "0px",
        top: adjustedPosition ? `${adjustedPosition.y}px` : "0px",
      }}
    >
      {items.map((item) => (
        <button
          key={item.key}
          type="button"
          onClick={() => {
            item.onClick();
            onClose();
          }}
          className="w-full px-4 py-2 text-left flex text-sm items-center gap-3 hover:bg-accent-200 text-selected transition-colors cursor-pointer"
        >
          <span>{item.label}</span>
        </button>
      ))}
    </div>
  );
}

export function ContextMenuProvider({ children }: PropsWithChildren) {
  const [items, setItems] = useState<ContextMenuItem[]>([]);
  const [position, setPosition] = useState<ContextMenuPosition | null>(null);

  function createContextMenu<T>(
    itemsOrFunction: ContextMenuInput,
  ): MouseEventHandler<T> {
    return (e: ReactMouseEvent<T>) => {
      e.preventDefault();

      if (typeof itemsOrFunction === "function") {
        setItems(itemsOrFunction());
      } else {
        setItems(itemsOrFunction);
      }

      setPosition({
        x: e.clientX,
        y: e.clientY,
      });

      return e;
    };
  }

  const closeContextMenu = () => {
    setItems([]);
    setPosition(null);
  };

  return (
    <ContextMenuContext.Provider
      value={{ createContextMenu, closeContextMenu }}
    >
      {children}
      {position && (
        <ContextMenu
          position={position}
          items={items}
          onClose={closeContextMenu}
        />
      )}
    </ContextMenuContext.Provider>
  );
}
