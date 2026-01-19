import {
  type DragEvent,
  type PropsWithChildren,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useEffect,
  useRef,
  useState,
} from "react";
import { isMacOS } from "../constants/isMacOS";
import { type ContextMenuItem, useContextMenu } from "../hooks/useContextMenu";
import i18next from "../i18next";

export interface ListItemState {
  isSelected: boolean;
  isDragging: boolean;
  isFocused: boolean;
}

export interface ListItem {
  id: string;
  selectable?: boolean;
}

type BaseProps<T> = {
  items: ListItem[];
  selectedIds: Set<string>;
  multiple: boolean;
  defaultFocusId?: string;
  defaultFocusType?: ScrollLogicalPosition;
  onChange: (selectedIds: Set<string>) => void;
  onDelete?: (selectedIds: Set<string>) => void;
  onSubmit?: (selectedIds: Set<string>) => void;
  onDoubleClick?: (item: T) => void;
  onDrop?: (
    droppedIds: Set<string>,
    droppedAtIndex: number,
    sourceListId: string,
  ) => void;
  onContextMenu?: (selectedIds: Set<string>) => ContextMenuItem[];
  renderItem: (item: T, state: ListItemState) => ReactNode;
};

type DragProps =
  | { allowDrag?: false; allowDropFrom?: string[]; id?: never }
  | { allowDrag: true; allowDropFrom?: string[]; id: string }
  | { allowDrag?: boolean; allowDropFrom: string[]; id: string };

export function SelectableList<T>({
  id: listId,
  items,
  selectedIds,
  onChange,
  onDelete,
  onDrop,
  onSubmit,
  onDoubleClick,
  onContextMenu,
  renderItem,
  defaultFocusId,
  defaultFocusType = "nearest",
  multiple: allowMultiple,
  allowDrag = false,
  allowDropFrom = [],
}: PropsWithChildren<BaseProps<T> & DragProps>) {
  const listRef = useRef<HTMLDivElement>(null);
  const [scrollBlockType, setScrollBlockType] = useState<
    ScrollLogicalPosition | undefined
  >(defaultFocusType);
  const [focusedIndex, setFocusedIndex] = useState<number>(-1);
  const lastSelectedIndexRef = useRef<number>(0);
  const { createContextMenu } = useContextMenu();
  const [draggingIds, setDraggingIds] = useState<Set<string>>(new Set());
  const [dropAtIndex, setDropAtIndex] = useState<number | null>(null);
  const allowDrop = allowDropFrom.length !== 0;

  // Reset when items change
  useEffect(() => {
    const defaultIndex = items.findIndex((item) => defaultFocusId === item.id);

    setFocusedIndex(defaultIndex);
    lastSelectedIndexRef.current = defaultIndex;
  }, [items, defaultFocusId]);

  // Scroll focussed item into view, which is to make the experience feel
  // better when using keyboard arrow navigation.
  useEffect(() => {
    const listElement = listRef.current;
    if (!listElement) return;
    if (focusedIndex === -1) return;

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

    if (onDelete && (e.key === "Backspace" || e.key === "Delete")) {
      e.preventDefault();
      onDelete(selectedIds);
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

  const handleDragStart = (index: number, e: DragEvent) => {
    const item = items[index];
    if (item.selectable === false) {
      e.preventDefault();
      return;
    }

    // Determine current selection, if dragging starts on an element
    // that is not selected we overwrite the selection to just that item.
    let currentSelection: string[];
    if (!selectedIds.has(item.id)) {
      currentSelection = [item.id];
      const newSelection = new Set([item.id]);
      onChange(newSelection);
      setFocusedIndex(index);
      setScrollBlockType("nearest");
      lastSelectedIndexRef.current = index;
    } else {
      currentSelection = Array.from(selectedIds);
    }

    // Store this so we can update item states
    setDraggingIds(new Set(currentSelection));

    // Configure the dragging dataTransfer
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData(
      "application/json",
      JSON.stringify({
        sourceListId: listId,
        itemIds: currentSelection,
      }),
    );

    // Create custom drag image showing selection count
    const dragImage = document.createElement("div");
    dragImage.classList.add(
      "absolute",
      "py-1.5",
      "px-3",
      "rounded-md",
      "font-light",
      "text-white",
      "bg-accent-500",
      "shadow-lg",
      "text-sm",
    );

    dragImage.textContent = i18next.t("selection.dragItems", {
      defaultValue: "{{ count }} items",
      count: currentSelection.length,
    });

    document.body.appendChild(dragImage);
    e.dataTransfer.setDragImage(dragImage, 0, 30);

    // If we delete it immediately it fails to become a drag image.
    requestAnimationFrame(() => document.body.removeChild(dragImage));
  };

  const handleDragEnd = () => {
    setDraggingIds(new Set());
    setDropAtIndex(null);
  };

  const handleDragOver = (e: DragEvent) => {
    const listElement = listRef.current;
    if (!listElement) return null;

    e.preventDefault();
    e.stopPropagation();

    // Find nearest index where items are dragged to.
    const children = Array.from(listElement.children);

    // Default dropIndex is at end of list.
    let dropIndex = items.length;
    for (let i = 0; i < children.length; i++) {
      const child = children[i] as HTMLElement;
      const rect = child.getBoundingClientRect();
      const midpoint = rect.top + rect.height / 2;

      if (e.clientY < midpoint) {
        dropIndex = i;
        break;
      }
    }

    setDropAtIndex(dropIndex);
  };

  const handleDragLeave = (e: DragEvent) => {
    // We have to make sure it is actually leaving the list element.
    const rect = listRef.current?.getBoundingClientRect();
    if (
      rect &&
      (e.clientX < rect.left ||
        e.clientX > rect.right ||
        e.clientY < rect.top ||
        e.clientY > rect.bottom)
    ) {
      setDropAtIndex(null);
    }
  };

  const handleDrop = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();

    const insertAtIndex = dropAtIndex !== null ? dropAtIndex : items.length;

    setDropAtIndex(null);

    if (!onDrop) return;

    try {
      const { sourceListId, itemIds } = JSON.parse(
        e.dataTransfer.getData("application/json"),
      );
      if (allowDropFrom.indexOf(sourceListId) === -1) return;
      onDrop(new Set(itemIds), insertAtIndex, sourceListId);
    } catch (_error) {
      /* invalid json */
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
        const isDragging = draggingIds.has(item.id);
        const isFocused = index === focusedIndex;
        const selectable = item.selectable !== false;
        const showDropTargetLine = dropAtIndex === index;

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
            draggable={allowDrag ? selectable : undefined}
            onDragStart={
              allowDrag ? (e) => handleDragStart(index, e) : undefined
            }
            onDragEnd={allowDrag ? handleDragEnd : undefined}
            onDragOver={allowDrop ? handleDragOver : undefined}
            onDragLeave={allowDrop ? handleDragLeave : undefined}
            onDrop={allowDrop ? handleDrop : undefined}
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
                      setScrollBlockType("nearest");
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
            className="relative"
          >
            {showDropTargetLine && (
              <div className="absolute top-0 left-0 right-0 h-0.5 bg-accent-500 z-10"></div>
            )}
            {renderItem(item as T, { isSelected, isDragging, isFocused })}
          </div>
        );
      })}
      {dropAtIndex === items.length && (
        <div className="relative h-0 overflow-visible">
          <div className="absolute bottom-0.5 left-0 right-0 h-0.5 bg-accent-500 z-10"></div>
        </div>
      )}
    </div>
  );
}
