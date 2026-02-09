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

export interface ContextMenuItem {
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
  const menuRef = useRef<HTMLDialogElement>(null);
  const [adjustedPosition, setAdjustedPosition] = useState<{
    x: number;
    y: number;
  } | null>(null);

  useEffect(() => {
    const menu = menuRef.current;
    if (!menu) return;

    // If there is no position we should hide the context menu.
    if (!position) {
      menuRef.current?.close();
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
    requestAnimationFrame(() => menuRef.current?.showModal());
  }, [position]);

  useEffect(() => {
    // Close on click outside of context menu
    const handleClick = (e: MouseEvent) => {
      if (!menuRef.current) return;

      if (!menuRef.current.contains(e.target as Node)) {
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
        onClose();
      }
    };

    // Close on Escape button pressed
    // TODO: Maybe need more generic Keyboard handler in the near future.
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        onClose();
      }
    };

    document.addEventListener("mousedown", handleClick);
    document.addEventListener("keydown", handleEscape, true);

    return () => {
      document.removeEventListener("mousedown", handleClick);
      document.removeEventListener("keydown", handleEscape, true);
    };
  }, [onClose]);

  useEffect(() => {
    menuRef.current?.showModal();
  }, []);

  return (
    <dialog
      ref={menuRef}
      className={classNames([
        "fixed bg-accent-50 text-selected transition-colors rounded-lg shadow-2xl border border-accent-200/50 py-1 min-w-48 z-50",
        "transition-opacity duration-75 dialog-contextmenu p-1",
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
          className={classNames([
            "w-full px-4 py-2 text-left flex text-sm items-center gap-3 rounded-md",
            "outline-none hover:bg-accent-200 text-selected transition-colors cursor-pointer",
          ])}
        >
          <span>{item.label}</span>
        </button>
      ))}
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
