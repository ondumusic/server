import {
  type DragEvent,
  type PropsWithChildren,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useEffect,
  useMemo,
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
  itemHeight?: "auto" | number | ((item: T) => number);
  scrollOverscan?: number;
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
  onTypeMatch?: (item: T, query: string) => boolean;
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
  onTypeMatch,
  renderItem,
  defaultFocusId,
  defaultFocusType = "nearest",
  multiple: allowMultiple,
  allowDrag = false,
  allowDropFrom = [],
  itemHeight: itemHeightSetting = "auto",
  scrollOverscan = 10,
}: PropsWithChildren<BaseProps<T> & DragProps>) {
  const listRef = useRef<HTMLDivElement>(null);
  const [scrollBlockType, setScrollBlockType] = useState<
    ScrollLogicalPosition | undefined
  >(defaultFocusType);
  const [focusedIndex, setFocusedIndex] = useState<number>(-1);
  const lastSelectedIndexRef = useRef<number>(0);
  const { createContextMenu } = useContextMenu();

  // Drag and Drop
  const [draggingIds, setDraggingIds] = useState<Set<string>>(new Set());
  const [dropAtIndex, setDropAtIndex] = useState<number | null>(null);
  const allowDrop = allowDropFrom.length !== 0;

  // Type matching
  const [typeMatch, setTypeMatch] = useState<string | null>(null);
  const typeMatchTimer = useRef<ReturnType<typeof setTimeout>>(null);

  // Virtual List
  const scrollThrottle = useRef<ReturnType<typeof requestAnimationFrame>>(null);
  const dummyItemRef = useRef<HTMLDivElement>(null);
  const [scrollTop, setScrollTop] = useState<number>(0);
  const [scrollHeight, setScrollHeight] = useState<number>(0);
  const [itemHeight, setItemHeight] = useState<number>(
    typeof itemHeightSetting === "number" ? itemHeightSetting : 0,
  );

  // Reset when items change
  useEffect(() => {
    const defaultIndex = items.findIndex((item) => defaultFocusId === item.id);

    setFocusedIndex(defaultIndex);
    lastSelectedIndexRef.current = defaultIndex;
  }, [items, defaultFocusId]);

  // Scroll to type match
  useEffect(() => {
    if (!onTypeMatch) return;
    if (!typeMatch) return;

    // Find the first item index that matches the query.
    const itemIndex = items.findIndex((item) =>
      onTypeMatch(item as T, typeMatch),
    );

    if (itemIndex !== -1) {
      // TODO: In my single use case I want it to select the item but it feels
      // a bit weird to do so maybe should revisit how this works.
      onChange(new Set([items[itemIndex].id]));
      setFocusedIndex(itemIndex);
      setScrollBlockType("nearest");
      lastSelectedIndexRef.current = itemIndex;
    }
  }, [typeMatch, onTypeMatch, onChange, items]);

  // Measure parent container (scroll area) height
  useEffect(() => {
    if (!listRef.current) return;

    const observer = new ResizeObserver((elements) => {
      const element = elements[0];

      if (element) {
        const measured = element.contentRect.height;
        if (measured > 0) {
          setScrollHeight(measured);
        }
      }
    });

    observer.observe(listRef.current);
    return () => observer.disconnect();
  }, []);

  // Measure example item height
  useEffect(() => {
    if (itemHeightSetting !== "auto") return;
    if (!dummyItemRef.current) return;

    const observer = new ResizeObserver((elements) => {
      const element = elements[0];
      if (element) {
        const measured = element.contentRect.height;
        if (measured > 0) {
          setItemHeight(measured);
        }
      }
    });

    observer.observe(dummyItemRef.current);
    return () => observer.disconnect();
  }, [itemHeightSetting]);

  // Calculate total height and offsets
  const { totalHeight, offsets } = useMemo(() => {
    const offsets: number[] = [0];
    let totalHeight = 0;

    for (let i = 0; i < items.length; i++) {
      const height =
        typeof itemHeightSetting === "function"
          ? itemHeightSetting(items[i] as T)
          : itemHeight;
      totalHeight += height;
      if (i < items.length - 1) {
        offsets.push(totalHeight);
      }
    }

    return { totalHeight, offsets };
  }, [items, itemHeight, itemHeightSetting]);

  // Find the first visible item
  const startIndex = useMemo(() => {
    let index = 0;
    for (let i = 0; i < items.length; i++) {
      const height =
        typeof itemHeightSetting === "function"
          ? itemHeightSetting(items[i] as T)
          : itemHeight;
      if (offsets[i] + height > scrollTop) {
        index = i;
        break;
      }
    }
    return Math.max(0, index - scrollOverscan);
  }, [
    scrollTop,
    offsets,
    items,
    scrollOverscan,
    itemHeight,
    itemHeightSetting,
  ]);

  // Find the last visible item
  const endIndex = useMemo(() => {
    const viewportBottom = scrollTop + scrollHeight;
    let index = startIndex;

    for (let i = startIndex; i < items.length; i++) {
      index = i;

      const height =
        typeof itemHeightSetting === "function"
          ? itemHeightSetting(items[i] as T)
          : itemHeight;
      if (offsets[i] + height > viewportBottom) {
        break;
      }
    }

    return Math.min(items.length - 1, index + scrollOverscan);
  }, [
    scrollTop,
    scrollHeight,
    startIndex,
    offsets,
    items,
    scrollOverscan,
    itemHeight,
    itemHeightSetting,
  ]);

  const scrollOffsetY = offsets[startIndex] || 0;

  const visibleItems = useMemo(
    () => items.slice(startIndex, endIndex + 1),
    [items, startIndex, endIndex],
  );

  // Scroll focussed item into view, which is to make the experience feel
  // better when using keyboard arrow navigation.
  useEffect(() => {
    const listElement = listRef.current;
    if (!listElement) return;
    if (focusedIndex === -1) return;

    const height =
      typeof itemHeightSetting === "function"
        ? itemHeightSetting(items[focusedIndex] as T)
        : itemHeight;

    const itemTop = offsets[focusedIndex] || 0;
    const itemBottom = itemTop + height;
    const viewportTop = scrollTop;
    const viewportBottom = scrollTop + scrollHeight;

    // If it's already visible then we can do nothing here.
    if (itemTop >= viewportTop && itemBottom <= viewportBottom) {
      return;
    }

    // Scroll to make item visible
    let scrollTo: number = 0;
    if (scrollBlockType === "center") {
      scrollTo = itemTop - scrollHeight / 2 + itemHeight / 2;
    } else if (scrollBlockType === "nearest") {
      if (itemTop < viewportTop) {
        // Item is above viewport - scroll up to show it at top
        scrollTo = itemTop;
      } else {
        // Item is below viewport - scroll down to show it at bottom
        scrollTo = itemBottom - scrollHeight;
      }
    }

    scrollTo = Math.max(0, scrollTo);

    listElement.scrollTo({
      top: scrollTo,
      behavior: "instant",
    });

    setScrollTop(scrollTo);
  }, [
    focusedIndex,
    items,
    itemHeight,
    itemHeightSetting,
    offsets,
    scrollBlockType,
    scrollHeight,
    scrollTop,
  ]);

  // Handle scroll with throttling
  useEffect(() => {
    if (!listRef.current) return;

    const handleScroll = () => {
      if (scrollThrottle.current) return;

      scrollThrottle.current = requestAnimationFrame(() => {
        if (listRef.current) {
          setScrollTop(listRef.current.scrollTop);
        }

        scrollThrottle.current = null;
      });
    };

    listRef.current.addEventListener("scroll", handleScroll, { passive: true });

    return () => {
      if (listRef.current) {
        listRef.current.removeEventListener("scroll", handleScroll);
      }
      if (scrollThrottle.current) {
        cancelAnimationFrame(scrollThrottle.current);
      }
    };
  }, []);

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

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (!onTypeMatch) return;
    if (e.ctrlKey || e.shiftKey || e.metaKey) return;

    const typeMatchTimerActive = typeMatchTimer.current !== null;
    if (typeMatchTimer.current) clearTimeout(typeMatchTimer.current);
    typeMatchTimer.current = setTimeout(() => {
      typeMatchTimer.current = null;
    }, 800);

    e.preventDefault();

    if (typeMatchTimerActive) {
      setTypeMatch(`${typeMatch ?? ""}${e.key}`);
    } else {
      setTypeMatch(e.key);
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

      if (onTypeMatch) {
        setTypeMatch(null);
        if (typeMatchTimer.current) clearTimeout(typeMatchTimer.current);
        typeMatchTimer.current = null;
      }
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
    const mouseY = e.clientY;

    // Quick checks
    if (children.length === 0) return items.length;
    if (mouseY < children[0].getBoundingClientRect().top) return 0;
    if (mouseY > children[children.length - 1].getBoundingClientRect().bottom)
      return items.length;

    // Default dropIndex is at end of list.
    let dropIndex = items.length;

    // Binary search
    let low = 0,
      high = children.length - 1;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      const rect = children[mid].getBoundingClientRect();
      const midpoint = rect.top + rect.height / 2;

      if (mouseY < midpoint) {
        dropIndex = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
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
      className="focus:outline-none select-none selectable-list h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      tabIndex={0}
      onKeyDown={handleKeyDown}
      onKeyPress={handleKeyPress}
      role="listbox"
      aria-multiselectable={allowMultiple}
    >
      {itemHeightSetting === "auto" && items.length > 0 && (
        <div
          ref={dummyItemRef}
          className="absolute pointer-events-none invisible -top-[999px]"
        >
          {renderItem(items[0] as T, {
            isSelected: false,
            isDragging: false,
            isFocused: false,
          })}
        </div>
      )}

      <div className="relative" style={{ height: totalHeight }}>
        <div
          className="will-change-transform"
          style={{ transform: `translateY(${scrollOffsetY}px)` }}
        >
          {visibleItems.map((item, visibleIndex) => {
            const index = startIndex + visibleIndex;
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

                          // Only update selection if the item is selectable
                          // this way we can allow context menus on non-selectable
                          // items too.
                          if (item.selectable !== false) {
                            onChange(newSelection);
                            setFocusedIndex(index);
                            setScrollBlockType("nearest");
                            lastSelectedIndexRef.current = index;
                          }

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
      </div>
    </div>
  );
}
