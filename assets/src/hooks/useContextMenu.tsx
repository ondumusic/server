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
      onClick(): void;
    };

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

      // Calculate the position for the context menu that ideally
      // fits within the viewport bounds.
      const rect = menu.getBoundingClientRect();
      const viewport = {
        width: window.innerWidth,
        height: window.innerHeight,
      };

      let { x, y } = position;

      if (x + rect.width > viewport.width) {
        x = viewport.width - rect.width - 16;
      }
      if (x < 0) x = 16;

      if (y + rect.height > viewport.height) {
        y = viewport.height - rect.height - 16;
      }
      if (y < 0) y = 16;

      // Update the position of the context menu
      setAdjustedPosition({ x, y });

      // Make the modal visible
      setIsVisible(true);
      menuRef.current?.showModal();
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

  // On mount immediately show the modal
  useEffect(() => {
    setFocusedIndex(0);
    menuRef.current?.showModal();
  }, []);

  return (
    <dialog
      ref={menuRef}
      className={classNames([
        "fixed bg-stone-100 text-selected transition-colors rounded-lg shadow-2xl border border-stone-200/50 py-1 min-w-48 max-w-64 z-50",
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
                className="my-1 h-[1px] mx-4 overflow-hidden bg-stone-200"
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
                  "outline-none text-selected transition-colors cursor-pointer",
                  focusedIndex === menuItemIndex && "bg-blue-400 text-white",
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
    itemsOrFunction: ContextMenuInput,
  ): MouseEventHandler<T> {
    return (e: ReactMouseEvent<T>) => {
      e.preventDefault();

      let newItems: ContextMenuItem[] = [];
      if (typeof itemsOrFunction === "function") {
        newItems = itemsOrFunction();
      } else {
        newItems = itemsOrFunction;
      }

      setItems(newItems);
      if (newItems.length === 0) return;

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
