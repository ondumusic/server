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

export interface Item {
  id: string;
  selectable?: boolean;
}

export function SelectableList<T>({
  items,
  selectedIds,
  onChange,
  onSubmit,
  renderItem,
}: PropsWithChildren<{
  items: Item[];
  selectedIds: Set<string>;
  onChange: (selectedIds: Set<string>) => void;
  onSubmit: (selectedIds: Set<string>) => void;
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
    const item = items[index];
    if (item.selectable === false) return;

    const isMultiSelect = isMacOS ? e.metaKey : e.ctrlKey;
    const isRangeSelect = e.shiftKey;

    if (isRangeSelect && selectedIds.size > 0) {
      const start = Math.min(lastSelectedIndexRef.current, index);
      const end = Math.max(lastSelectedIndexRef.current, index);
      const newSelected = new Set(selectedIds);

      for (let i = start; i <= end; i++) {
        if (items[i].selectable !== false) {
          newSelected.add(items[i].id);
        }
      }

      onChange(newSelected);
      setFocusedIndex(index);
    } else if (isMultiSelect) {
      const newSelected = new Set(selectedIds);

      if (newSelected.has(item.id)) {
        newSelected.delete(item.id);
      } else {
        newSelected.add(item.id);
      }

      onChange(newSelected);
      setFocusedIndex(index);
      lastSelectedIndexRef.current = index;
    } else {
      onChange(new Set([item.id]));
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
      onChange(new Set(items.map((item) => item.id)));
      return;
    }

    // Deselect all
    if (e.key === "Escape") {
      e.preventDefault();
      onChange(new Set());
      return;
    }

    // Submit selection
    if (e.key === "Enter") {
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

        if (isRangeSelect) {
          const start = Math.min(lastSelectedIndexRef.current, newIndex);
          const end = Math.max(lastSelectedIndexRef.current, newIndex);
          const newSelected = new Set<string>();

          for (let i = start; i <= end; i++) {
            if (items[i].selectable !== false) {
              newSelected.add(items[i].id);
            }
          }

          onChange(newSelected);
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

        if (isRangeSelect) {
          const start = Math.min(lastSelectedIndexRef.current, newIndex);
          const end = Math.max(lastSelectedIndexRef.current, newIndex);
          const newSelected = new Set<string>();

          for (let i = start; i <= end; i++) {
            if (items[i].selectable !== false) {
              newSelected.add(items[i].id);
            }
          }

          onChange(newSelected);
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
      aria-multiselectable="true"
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
