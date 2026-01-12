import {
  type PropsWithChildren,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useEffect,
  useRef,
  useState,
} from "react";
import { isMacOS } from "../constants/isMacOS";

interface ItemState {
  isSelected: boolean;
  isFocused: boolean;
}

export function SelectableList<T>({
  items,
  selectedIds,
  onSelectionChange,
  isItemSelectable,
  getItemId,
  renderItem,
}: PropsWithChildren<{
  items: T[];
  selectedIds: Set<string>;
  isItemSelectable: (item: T) => boolean;
  onSelectionChange: (selectedIds: Set<string>) => void;
  getItemId: (item: T) => string;
  renderItem: (item: T, state: ItemState) => ReactNode;
}>) {
  const listRef = useRef<HTMLDivElement>(null);
  const [focusedIndex, setFocusedIndex] = useState<number>(0);
  const lastSelectedIndexRef = useRef<number>(0);

  // Scroll focussed item into view, which is to make the experience feel
  // better when using keyboard arrow navigation.
  useEffect(() => {
    const listElement = listRef.current;
    if (!listElement) return;

    const focusedElement = listElement.children[focusedIndex] as HTMLElement;
    if (focusedElement) {
      focusedElement.scrollIntoView({ block: "nearest", behavior: "smooth" });
    }
  }, [focusedIndex]);

  const handleItemClick = (index: number, e: ReactMouseEvent) => {
    if (!isItemSelectable(items[index])) return;

    const itemId = getItemId(items[index]);
    const isMultiSelect = isMacOS ? e.metaKey : e.ctrlKey;
    const isRangeSelect = e.shiftKey;

    if (isRangeSelect && selectedIds.size > 0) {
      const start = Math.min(lastSelectedIndexRef.current, index);
      const end = Math.max(lastSelectedIndexRef.current, index);
      const newSelected = new Set(selectedIds);

      for (let i = start; i <= end; i++) {
        if (isItemSelectable(items[i])) {
          newSelected.add(getItemId(items[i]));
        }
      }

      onSelectionChange(newSelected);
      setFocusedIndex(index);
    } else if (isMultiSelect) {
      const newSelected = new Set(selectedIds);

      if (newSelected.has(itemId)) {
        newSelected.delete(itemId);
      } else {
        newSelected.add(itemId);
      }

      onSelectionChange(newSelected);
      setFocusedIndex(index);
      lastSelectedIndexRef.current = index;
    } else {
      onSelectionChange(new Set([itemId]));
      setFocusedIndex(index);
      lastSelectedIndexRef.current = index;
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    const isMultiSelect = isMacOS ? e.metaKey : e.ctrlKey;
    const isRangeSelect = e.shiftKey;

    // Select all
    if (e.key === "a" && isMultiSelect) {
      e.preventDefault();
      onSelectionChange(new Set(items.map((item) => getItemId(item))));
      return;
    }

    // Deselect all
    if (e.key === "Escape") {
      e.preventDefault();
      onSelectionChange(new Set());
      return;
    }

    // Keyboard arrow navigation
    if (e.key === "ArrowDown") {
      e.preventDefault();
      let newIndex = focusedIndex + 1;

      // Skip non-selectable items
      while (newIndex < items.length && !isItemSelectable(items[newIndex])) {
        newIndex++;
      }

      if (newIndex < items.length) {
        setFocusedIndex(newIndex);

        if (isRangeSelect) {
          const start = Math.min(lastSelectedIndexRef.current, newIndex);
          const end = Math.max(lastSelectedIndexRef.current, newIndex);
          const newSelected = new Set<string>();

          for (let i = start; i <= end; i++) {
            if (isItemSelectable(items[i])) {
              newSelected.add(getItemId(items[i]));
            }
          }

          onSelectionChange(newSelected);
        } else if (!isMultiSelect) {
          onSelectionChange(new Set([getItemId(items[newIndex])]));
          lastSelectedIndexRef.current = newIndex;
        }
      }
      return;
    }

    if (e.key === "ArrowUp") {
      e.preventDefault();
      let newIndex = focusedIndex - 1;

      // Skip non-selectable items
      while (newIndex >= 0 && !isItemSelectable(items[newIndex])) {
        newIndex--;
      }

      if (newIndex >= 0) {
        setFocusedIndex(newIndex);

        if (isRangeSelect) {
          const start = Math.min(lastSelectedIndexRef.current, newIndex);
          const end = Math.max(lastSelectedIndexRef.current, newIndex);
          const newSelected = new Set<string>();

          for (let i = start; i <= end; i++) {
            if (isItemSelectable(items[i])) {
              newSelected.add(getItemId(items[i]));
            }
          }

          onSelectionChange(newSelected);
        } else if (!isMultiSelect) {
          onSelectionChange(new Set([getItemId(items[newIndex])]));
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
      aria-multiselectable="true"
    >
      {items.map((item, index) => {
        const itemId = getItemId(item);
        const isSelected = selectedIds.has(itemId);
        const isFocused = index === focusedIndex;
        const selectable = isItemSelectable(item);

        return (
          // biome-ignore lint/a11y/useFocusableInteractive: arrow keys used for navigation
          // biome-ignore lint/a11y/useKeyWithClickEvents: events handled elsewhere
          <div
            key={getItemId(item)}
            onClick={(e) => handleItemClick(index, e)}
            role="option"
            aria-selected={selectable ? isSelected : undefined}
            aria-disabled={!selectable}
          >
            {renderItem(item, { isSelected, isFocused })}
          </div>
        );
      })}
    </div>
  );
}
