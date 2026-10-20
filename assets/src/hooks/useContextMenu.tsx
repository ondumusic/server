import {
  createContext,
  type MouseEventHandler,
  type PropsWithChildren,
  type MouseEvent as ReactMouseEvent,
  useContext,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { classNames } from "../utils/classNames";

interface ContextMenuPosition {
  x: number;
  y: number;
}

export type ContextMenuItem =
  | {
      type: "divider";
      key: string;
    }
  | {
      type: string;
      key: string;
      label: string;
      danger?: boolean;
      onClick(): void;
    };

type ContextMenuFunction<T> = (
  e: ReactMouseEvent<T>,
) => ContextMenuItem[] | Promise<ContextMenuItem[]>;
type ContextMenuInput<T> = ContextMenuItem[] | ContextMenuFunction<T>;

interface ContextMenuContextValue {
  createContextMenu<T>(
    itemsOrFunction: ContextMenuInput<T>,
  ): MouseEventHandler<T>;
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
  const menuRef = useRef<HTMLDialogElement>(null);
  const [focusedIndex, setFocusedIndex] = useState(0);
  const [isVisible, setIsVisible] = useState(false);
  const [adjustedPosition, setAdjustedPosition] = useState<{
    x: number;
    y: number;
  } | null>(null);

  const menuItems = useMemo(() => {
    return items.filter((item) => item.type === "item");
  }, [items]);

  useLayoutEffect(() => {
    const raf = requestAnimationFrame(() => {
      const menu = menuRef.current;
      if (!menu) return;

      // If there is no position we should hide the context menu.
      if (!position) {
        menuRef.current?.close();
        setIsVisible(false);
        return;
      }

      // We'll need to "show" the modal (still invisible) to measure it,
      // because a closed dialog has no size. The visibility is controlled
      // with the isVisible state.
      if (menu.open) menu.close();
      menu.showModal();

      // Now we can calculate the position for the context menu to ensure it
      // fits within the viewport.
      const rect = menu.getBoundingClientRect();
      const viewport = {
        width: window.innerWidth,
        height: window.innerHeight,
      };
      const margin = 16;

      let { x, y } = position;

      const fitsRight = x + rect.width <= viewport.width - margin;
      if (!fitsRight) x = position.x - rect.width;
      if (x < margin) x = margin;

      const fitsBelow = y + rect.height <= viewport.height - margin;
      if (!fitsBelow) y = position.y - rect.height;
      if (y < margin) y = margin;

      // Update the position of the context menu
      setAdjustedPosition({ x, y });

      // Make the modal visible
      setIsVisible(true);
    });
    return () => cancelAnimationFrame(raf);
  }, [position]);

  useEffect(() => {
    // Close on click outside of context menu
    const handleClick = (e: MouseEvent) => {
      if (!menuRef.current) return;

      if (!menuRef.current.contains(e.target as Node)) {
        setIsVisible(false);
        onClose();
        return;
      }

      // For <dialog> the click on modal backdrop counts as clicking within
      // the modal so we can compare coordinates to see if it's inside or out.
      const modalRect = menuRef.current.getBoundingClientRect();
      if (
        e.clientX < modalRect.left ||
        e.clientX > modalRect.right ||
        e.clientY < modalRect.top ||
        e.clientY > modalRect.bottom
      ) {
        setIsVisible(false);
        onClose();
      }
    };

    // Handle keyboard button presses
    const handleKeyDown = (e: KeyboardEvent) => {
      switch (e.key) {
        case "Escape":
          e.stopPropagation();
          setIsVisible(false);
          onClose();
          break;

        case "ArrowDown":
          e.preventDefault();
          setFocusedIndex((prev) => Math.min(menuItems.length - 1, prev + 1));
          break;

        case "ArrowUp":
          e.preventDefault();
          setFocusedIndex((prev) => Math.max(0, prev - 1));
          break;

        case "Enter":
        case " ": {
          e.preventDefault();

          const menuItem = menuItems[focusedIndex];
          if (menuItem && menuItem.type === "item") {
            menuItem.onClick();
            setIsVisible(false);
            onClose();
          }

          break;
        }
      }
    };

    document.addEventListener("mousedown", handleClick);
    document.addEventListener("keydown", handleKeyDown, true);

    return () => {
      document.removeEventListener("mousedown", handleClick);
      document.removeEventListener("keydown", handleKeyDown, true);
    };
  }, [onClose, focusedIndex, menuItems]);

  // On mount default focus index to first item
  useEffect(() => {
    setFocusedIndex(0);
  }, []);

  return (
    <dialog
      ref={menuRef}
      className={classNames([
        "fixed bg-contextmenu-bg text-selected transition-colors rounded-lg shadow-2xl border border-contextmenu-border py-1 min-w-48 max-w-64 max-h-[calc(100vh-2rem)] overflow-y-auto z-50",
        "transition-opacity duration-75 dialog-contextmenu p-1 space-y-0.5",
        !isVisible && "invisible",
      ])}
      style={{
        left: adjustedPosition ? `${adjustedPosition.x}px` : "0px",
        top: adjustedPosition ? `${adjustedPosition.y}px` : "0px",
      }}
    >
      {items.map((item) => {
        // The items index and menuItems index can differ because of non-selectable elements
        const menuItemIndex = menuItems.indexOf(item);

        switch (item.type) {
          case "divider":
            return (
              <div
                key={item.key}
                className="my-1 h-[1px] mx-4 overflow-hidden bg-contextmenu-divider"
              ></div>
            );

          case "item":
            return (
              <button
                key={item.key}
                type="button"
                onClick={() => {
                  item.onClick();
                  onClose();
                }}
                onMouseMove={() => {
                  setFocusedIndex(menuItemIndex);
                }}
                className={classNames([
                  "w-full px-4 py-2 text-left flex text-sm items-center gap-3 rounded-md",
                  "outline-none transition-colors cursor-pointer",
                  item.danger === true ? "text-error" : "text-contextmenu-fg",
                  focusedIndex === menuItemIndex &&
                    item.danger === true &&
                    "bg-error text-white",
                  focusedIndex === menuItemIndex &&
                    item.danger !== true &&
                    "bg-accent-400 text-white",
                ])}
              >
                <span className="block overflow-hidden text-ellipsis whitespace-nowrap">
                  {item.label}
                </span>
              </button>
            );

          default:
            return null;
        }
      })}
    </dialog>
  );
}

export function ContextMenuProvider({ children }: PropsWithChildren) {
  const [items, setItems] = useState<ContextMenuItem[]>([]);
  const [position, setPosition] = useState<ContextMenuPosition | null>(null);

  function createContextMenu<T>(
    itemsOrFunction: ContextMenuInput<T>,
  ): MouseEventHandler<T> {
    return (e: ReactMouseEvent<T>) => {
      e.preventDefault();
      // e.stopPropagation();

      let itemsPromise: Promise<ContextMenuItem[]>;
      if (typeof itemsOrFunction === "function") {
        const items = itemsOrFunction(e);
        if (items instanceof Promise) {
          itemsPromise = items;
        } else {
          itemsPromise = Promise.resolve(items as ContextMenuItem[]);
        }
      } else {
        itemsPromise = Promise.resolve(itemsOrFunction);
      }

      const newPosition = {
        x: e.clientX,
        y: e.clientY,
      };

      if (!itemsPromise) return e;
      itemsPromise.then((items: ContextMenuItem[]) => {
        if (items.length === 0) return;
        setItems(items);
        setPosition(newPosition);
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
