import {
  type PropsWithChildren,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useEffect,
  useRef,
  useState,
} from "react";
import { isMacOS } from "../constants/isMacOS";
import { type ContextMenuItem, useContextMenu } from "../hooks/useContextMenu";

interface ItemState {
  isSelected: boolean;
  isFocused: boolean;
}

export interface ListItem {
  id: string;
  selectable?: boolean;
}

export function SelectableList<T>({
  items,
  selectedIds,
  onChange,
  onSubmit,
  onDoubleClick,
  onContextMenu,
  renderItem,
  defaultFocusId,
  defaultFocusType = "nearest",
  multiple: allowMultiple,
}: PropsWithChildren<{
  items: ListItem[];
  selectedIds: Set<string>;
  multiple: boolean;
  defaultFocusId?: string;
  defaultFocusType?: ScrollLogicalPosition;
  onChange: (selectedIds: Set<string>) => void;
  onSubmit?: (selectedIds: Set<string>) => void;
  onDoubleClick?: (item: T) => void;
  onContextMenu?: (selectedIds: Set<string>) => ContextMenuItem[];
  renderItem: (item: T, state: ItemState) => ReactNode;
}>) {
  const listRef = useRef<HTMLDivElement>(null);
  const [scrollBlockType, setScrollBlockType] = useState<
    ScrollLogicalPosition | undefined
  >(defaultFocusType);
  const [focusedIndex, setFocusedIndex] = useState<number>(0);
  const lastSelectedIndexRef = useRef<number>(0);
  const { createContextMenu } = useContextMenu();

  // Reset when items change
  useEffect(() => {
    const defaultIndex = Math.max(
      0,
      items.findIndex((item) => defaultFocusId === item.id),
    );

    setFocusedIndex(defaultIndex);
    lastSelectedIndexRef.current = defaultIndex;
  }, [items, defaultFocusId]);

  // Scroll focussed item into view, which is to make the experience feel
  // better when using keyboard arrow navigation.
  useEffect(() => {
    const listElement = listRef.current;
    if (!listElement) return;
    if (focusedIndex === 0) return;

    const focusedElement = listElement.children[focusedIndex] as HTMLElement;
    if (focusedElement) {
      focusedElement.scrollIntoView({
        block: scrollBlockType,
        behavior: "instant",
      });
    }
  }, [focusedIndex, scrollBlockType]);

  const handleItemClick = (index: number, e: ReactMouseEvent) => {
    const item = items[index];
    if (item.selectable === false) return;

    const isMultiSelect = allowMultiple && (isMacOS ? e.metaKey : e.ctrlKey);
    const isRangeSelect = allowMultiple && e.shiftKey;

    if (isRangeSelect && selectedIds.size > 0) {
      const start = Math.min(lastSelectedIndexRef.current, index);
      const end = Math.max(lastSelectedIndexRef.current, index);
      const newSelection = new Set(selectedIds);

      for (let i = start; i <= end; i++) {
        if (items[i].selectable !== false) {
          newSelection.add(items[i].id);
        }
      }

      onChange(newSelection);
      setFocusedIndex(index);
      setScrollBlockType("nearest");
    } else if (isMultiSelect) {
      const newSelection = new Set(selectedIds);

      if (newSelection.has(item.id)) {
        newSelection.delete(item.id);
      } else {
        newSelection.add(item.id);
      }

      onChange(newSelection);
      setFocusedIndex(index);
      setScrollBlockType("nearest");
      lastSelectedIndexRef.current = index;
    } else {
      onChange(new Set([item.id]));
      setFocusedIndex(index);
      setScrollBlockType("nearest");
      lastSelectedIndexRef.current = index;
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    const isMultiSelect = allowMultiple && (isMacOS ? e.metaKey : e.ctrlKey);
    const isRangeSelect = allowMultiple && e.shiftKey;

    // Select all
    if (e.key === "a" && isMultiSelect) {
      e.preventDefault();
      onChange(
        new Set(
          items
            .filter((item) => item.selectable !== false)
            .map((item) => item.id),
        ),
      );
      return;
    }

    // Deselect all
    if (e.key === "Escape") {
      e.preventDefault();
      onChange(new Set());
      return;
    }

    // Submit selection
    if (onSubmit && e.key === "Enter") {
      e.preventDefault();
      onSubmit(selectedIds);
      return;
    }

    // Keyboard arrow navigation
    if (e.key === "ArrowDown") {
      e.preventDefault();
      let newIndex = focusedIndex + 1;

      // Skip non-selectable items
      while (newIndex < items.length && items[newIndex].selectable === false) {
        newIndex++;
      }

      if (newIndex < items.length) {
        setFocusedIndex(newIndex);
        setScrollBlockType("nearest");

        if (isRangeSelect) {
          const start = Math.min(lastSelectedIndexRef.current, newIndex);
          const end = Math.max(lastSelectedIndexRef.current, newIndex);
          const newSelection = new Set<string>();

          for (let i = start; i <= end; i++) {
            if (items[i].selectable !== false) {
              newSelection.add(items[i].id);
            }
          }

          onChange(newSelection);
        } else if (!isMultiSelect) {
          onChange(new Set([items[newIndex].id]));
          lastSelectedIndexRef.current = newIndex;
        }
      }
      return;
    }

    if (e.key === "ArrowUp") {
      e.preventDefault();
      let newIndex = focusedIndex - 1;

      // Skip non-selectable items
      while (newIndex >= 0 && items[newIndex].selectable === false) {
        newIndex--;
      }

      if (newIndex >= 0) {
        setFocusedIndex(newIndex);
        setScrollBlockType("nearest");

        if (isRangeSelect) {
          const start = Math.min(lastSelectedIndexRef.current, newIndex);
          const end = Math.max(lastSelectedIndexRef.current, newIndex);
          const newSelection = new Set<string>();

          for (let i = start; i <= end; i++) {
            if (items[i].selectable !== false) {
              newSelection.add(items[i].id);
            }
          }

          onChange(newSelection);
        } else if (!isMultiSelect) {
          onChange(new Set([items[newIndex].id]));
          lastSelectedIndexRef.current = newIndex;
        }
      }
      return;
    }
  };

  return (
    <div
      ref={listRef}
      className="focus:outline-none select-none"
      tabIndex={0}
      onKeyDown={handleKeyDown}
      role="listbox"
      aria-multiselectable={allowMultiple}
    >
      {items.map((item, index) => {
        const isSelected = selectedIds.has(item.id);
        const isFocused = index === focusedIndex;
        const selectable = item.selectable !== false;

        return (
          // biome-ignore lint/a11y/useFocusableInteractive: arrow keys used for navigation
          // biome-ignore lint/a11y/useKeyWithClickEvents: events handled elsewhere
          <div
            key={item.id}
            onClick={(e) => handleItemClick(index, e)}
            onDoubleClick={(e: ReactMouseEvent) => {
              if (!onDoubleClick) return;
              e.preventDefault();
              return onDoubleClick(item as T);
            }}
            onContextMenu={
              onContextMenu
                ? createContextMenu<HTMLDivElement>(() => {
                    // If the item that gets the context menu is not in the
                    // selection, we discard the entire selection and only
                    // select this item.
                    if (!isSelected) {
                      const newSelection = new Set([item.id]);
                      onChange(newSelection);
                      setFocusedIndex(index);
                      lastSelectedIndexRef.current = index;
                      return onContextMenu(newSelection);
                    }

                    // Otherwise just return the list of selectedIds
                    return onContextMenu(selectedIds);
                  })
                : undefined
            }
            role="option"
            aria-selected={selectable ? isSelected : undefined}
            aria-disabled={!selectable}
          >
            {renderItem(item as T, { isSelected, isFocused })}
          </div>
        );
      })}
    </div>
  );
}
