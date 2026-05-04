import {
  type DragEvent,
  type PropsWithChildren,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { isMacOS } from "../constants/isMacOS";
import { type ContextMenuItem, useContextMenu } from "../hooks/useContextMenu";
import i18next from "../i18next";
import { classNames } from "../utils/classNames";

export interface ListItemState {
  isSelected: boolean;
  isDragging: boolean;
  isFocused: boolean;
}

export interface ListItem {
  id: string;
  type?: string;
  selectable?: boolean;
}

export type KeyContext<T> = {
  focusedItem: T | null;
  focusedIndex: number;
  selectedIds: Set<string>;
};

type BaseProps<T> = {
  items: ListItem[];
  selectedIds: Set<string>;
  multiple: boolean;
  defaultFocusId?: string;
  defaultFocusType?: ScrollLogicalPosition;
  dropTargetClass?: string;
  itemHeight?: "auto" | number | ((item: T) => number);
  scrollOverscan?: number;
  paddingBottom?: number;
  paddingTop?: number;
  resetScrollOnItemsChange?: boolean;
  keyBindings?: Record<string, (ctx: KeyContext<T>) => void>;
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
  dropTargetClass = "bg-blue-500",
  resetScrollOnItemsChange = false,
  multiple: allowMultiple,
  keyBindings = {},
  allowDrag = false,
  allowDropFrom = [],
  itemHeight = "auto",
  scrollOverscan = 10,
  paddingBottom = 0,
  paddingTop = 0,
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
  const [scrollTop, setScrollTop] = useState<number>(0);
  const [scrollHeight, setScrollHeight] = useState<number>(0);
  const measureRefs = useRef<Map<string, HTMLDivElement>>(new Map());
  const [measuredHeights, setMeasuredHeights] = useState<Map<string, number>>(
    new Map(),
  );

  // Determine the first selectable index
  const firstSelectableIndex = useMemo(() => {
    const i = items.findIndex((item) => item.selectable !== false);
    return i === -1 ? items.length : i;
  }, [items]);

  // Get a list of unique item types
  const uniqueItemTypes = useMemo(() => {
    const types = new Set<string>();

    // We expect to see all different types inside the first 100 items.
    const sampleSize = Math.min(100, items.length);
    for (let i = 0; i < sampleSize; i++) {
      types.add(items[i].type ?? "default");
    }

    return Array.from(types);
  }, [items]);

  const getItemHeight = useCallback(
    (item?: ListItem) => {
      if (!item) return 0;

      let height: number = 0;
      if (itemHeight === "auto") {
        const type = item.type ?? "default";
        height = measuredHeights.get(type) ?? 40;
      } else if (typeof itemHeight === "number") {
        height = itemHeight;
      } else if (typeof itemHeight === "function") {
        height = itemHeight(item as T);
      }

      return height;
    },
    [itemHeight, measuredHeights],
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

  // Measure on on first render already
  useLayoutEffect(() => {
    if (!listRef.current) return;
    const elements = listRef.current.querySelectorAll("[data-type]");
    const handled = new Set();
    elements.forEach((el) => {
      const type = el.getAttribute("data-type");
      if (type) {
        if (handled.has(type)) return;
        measuredHeights.set(type, el.getBoundingClientRect().height);
        handled.add(type);
      }
    });
  }, [measuredHeights]);

  // Automatically determine item height for every type
  // biome-ignore lint/correctness/useExhaustiveDependencies(items): suppress dependency items as changing it might change size too
  useEffect(() => {
    if (itemHeight !== "auto") return;

    const observer = new ResizeObserver((entries) => {
      setMeasuredHeights((prev) => {
        let next: Map<string, number> | null = null;
        entries.forEach((entry) => {
          const typeKey = entry.target.getAttribute("data-type");
          if (!typeKey) return;
          const measured = entry.contentRect.height;
          if (measured > 0 && measured !== prev.get(typeKey)) {
            if (!next) next = new Map(prev);
            next.set(typeKey, measured);
          }
        });
        return next ?? prev;
      });
    });

    measureRefs.current.forEach((element) => {
      observer.observe(element);
    });
    return () => observer.disconnect();
  }, [items, itemHeight]);

  // Calculate total height and offsets
  const { totalItemsHeight, offsets } = useMemo(() => {
    const offsets: number[] = [0];
    let acc = 0;
    for (let i = 0; i < items.length; i++) {
      acc += getItemHeight(items[i]);
      if (i < items.length - 1) offsets.push(acc);
    }
    return { totalItemsHeight: acc, offsets };
  }, [items, getItemHeight]);
  const totalHeight = totalItemsHeight + paddingTop + paddingBottom;

  // Find the first visible item
  const startIndex = useMemo(() => {
    let index = 0;
    for (let i = 0; i < items.length; i++) {
      if (offsets[i] + getItemHeight(items[i]) > scrollTop) {
        index = i;
        break;
      }
    }
    return Math.max(0, index - scrollOverscan);
  }, [scrollTop, offsets, items, getItemHeight, scrollOverscan]);

  // Find the last visible item
  const endIndex = useMemo(() => {
    const viewportBottom = scrollTop + scrollHeight;
    let index = startIndex;

    for (let i = startIndex; i < items.length; i++) {
      index = i;

      if (offsets[i] + getItemHeight(items[i]) > viewportBottom) {
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
    getItemHeight,
    scrollOverscan,
  ]);

  const scrollOffsetY = offsets[startIndex] || 0;

  const visibleItems = useMemo(
    () => items.slice(startIndex, endIndex + 1),
    [items, startIndex, endIndex],
  );

  // Scroll focussed item into view, which is to make the experience feel
  // better when using keyboard arrow navigation.
  // biome-ignore lint/correctness/useExhaustiveDependencies(scrollTop): suppress dependency scrollTop otherwise this will execute on every scroll behaviour
  useEffect(() => {
    const listElement = listRef.current;
    if (!listElement) return;
    if (focusedIndex === -1) return;

    const height = getItemHeight(items[focusedIndex]);
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
      scrollTo = itemTop - scrollHeight / 2 + height / 2;
    } else if (scrollBlockType === "start") {
      scrollTo = paddingTop + itemTop;
    } else if (scrollBlockType === "nearest") {
      if (itemTop < viewportTop) {
        // Item is above viewport - scroll up to show it at top
        scrollTo = itemTop - paddingTop - paddingBottom;
      } else {
        // Item is below viewport - scroll down to show it at bottom
        scrollTo = paddingBottom + paddingTop + itemBottom - scrollHeight;
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
    offsets,
    scrollBlockType,
    getItemHeight,
    scrollHeight,
    paddingTop,
    paddingBottom,
  ]);

  // Reset scroll when items change
  // biome-ignore lint/correctness/useExhaustiveDependencies(items): suppress dependency
  useEffect(() => {
    if (!listRef.current) return;
    if (!resetScrollOnItemsChange) return;
    listRef.current.scrollTop = 0;
  }, [resetScrollOnItemsChange, items]);

  // Handle scroll with throttling
  useEffect(() => {
    if (!listRef.current) return;

    const handleScroll = () => {
      if (scrollThrottle.current) {
        cancelAnimationFrame(scrollThrottle.current);
      }

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

    // Process custom keybindings last
    const hasModifier = e.ctrlKey || e.metaKey || e.shiftKey || e.altKey;
    if (keyBindings[e.key] && !hasModifier) {
      e.preventDefault();
      keyBindings[e.key]({
        focusedItem: focusedIndex >= 0 ? (items[focusedIndex] as T) : null,
        focusedIndex,
        selectedIds,
      });
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

    // Pre-seed dropAtIndex to current item
    setDropAtIndex(index);

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
      "bg-blue-500",
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
    setTimeout(() => document.body.removeChild(dragImage), 0);
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

    // Calculate relative mouseY so we can compare it with offsets/item heights.
    const rect = listRef.current?.getBoundingClientRect();
    if (!rect) return;
    const mouseY = e.clientY - rect.top + scrollTop;

    // Quick checks
    if (offsets.length === 0 || mouseY < offsets[0]) {
      setDropAtIndex(0);
      return items.length;
    }
    if (
      mouseY >
      offsets[offsets.length - 1] + getItemHeight(items[offsets.length - 1])
    ) {
      setDropAtIndex(items.length);
      return;
    }

    // Default dropIndex is at end of list.
    let dropIndex = items.length;

    // Binary search
    let low = 0,
      high = offsets.length - 1;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      const rect = {
        top: offsets[mid],
        height: getItemHeight(items[mid]),
      };

      const midpoint = rect.top + rect.height / 2;

      if (mouseY < midpoint) {
        dropIndex = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    setDropAtIndex(Math.max(dropIndex, firstSelectableIndex));
  };

  const handleDragLeave = (e: DragEvent) => {
    const rect = listRef.current?.getBoundingClientRect();
    if (!rect) return;

    const outsideHorizontally = e.clientX < rect.left || e.clientX > rect.right;
    const aboveTop = e.clientY < rect.top;
    const belowBottom = e.clientY > rect.bottom;

    if (!outsideHorizontally && !aboveTop && !belowBottom) {
      return; // still inside, ignore
    }

    // if (belowBottom && !outsideHorizontally) {
    //   setDropAtIndex(items.length);
    // } else if (aboveTop && !outsideHorizontally) {
    //   setDropAtIndex(firstSelectableIndex);
    // } else {
    setDropAtIndex(null);
    // }
  };

  const handleDrop = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();

    let insertAtIndex = dropAtIndex !== null ? dropAtIndex : items.length;
    insertAtIndex = Math.max(insertAtIndex, firstSelectableIndex);

    setDropAtIndex(null);

    if (!onDrop) return;

    try {
      const { sourceListId, itemIds } = JSON.parse(
        e.dataTransfer.getData("application/json"),
      );
      if (allowDropFrom.indexOf(sourceListId) === -1) return;
      onDrop(new Set(itemIds), insertAtIndex, sourceListId);
      setFocusedIndex(insertAtIndex);
      lastSelectedIndexRef.current = insertAtIndex;
    } catch (_error) {
      /* invalid json */
    }
  };

  return (
    <div
      ref={listRef}
      className="focus:outline-none select-none selectable-list relative h-full overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      tabIndex={0}
      onKeyDown={handleKeyDown}
      onKeyPress={handleKeyPress}
      role="listbox"
      aria-multiselectable={allowMultiple}
      onDragOver={allowDrop ? handleDragOver : undefined}
      onDragLeave={allowDrop ? handleDragLeave : undefined}
      onDrop={allowDrop ? handleDrop : undefined}
      onContextMenu={
        onContextMenu
          ? createContextMenu<HTMLDivElement>(() => {
              return onContextMenu(new Set([]));
            })
          : undefined
      }
    >
      {itemHeight === "auto" &&
        items.length > 0 &&
        uniqueItemTypes.map((type) => {
          const sampleIndex =
            type === "default"
              ? 0
              : items.findIndex((item) => item.type === type);

          if (sampleIndex === -1) return null;

          return (
            <div
              key={`measure-${type}`}
              ref={(el) => {
                el
                  ? measureRefs.current.set(type, el)
                  : measureRefs.current.delete(type);
              }}
              data-type={type}
              className="flex absolute pointer-events-none invisible -top-[999px]"
            >
              {renderItem(items[sampleIndex] as T, {
                isSelected: false,
                isDragging: false,
                isFocused: false,
              })}
            </div>
          );
        })}

      <div className="relative" style={{ height: totalHeight }}>
        <div
          style={{
            paddingBottom,
            paddingTop,
            transform: `translate3d(0, ${scrollOffsetY}px, 0)`,
          }}
        >
          {visibleItems.map((item, visibleIndex) => {
            const index = startIndex + visibleIndex;
            const isSelected = selectedIds.has(item.id);
            const isDragging = draggingIds.has(item.id);
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
                draggable={allowDrag ? selectable : undefined}
                onDragStart={
                  allowDrag ? (e) => handleDragStart(index, e) : undefined
                }
                onDragEnd={allowDrag ? handleDragEnd : undefined}
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
                {renderItem(item as T, { isSelected, isDragging, isFocused })}
              </div>
            );
          })}
        </div>
      </div>
      {dropAtIndex !== null && (
        <div
          className={classNames([
            "absolute left-0 right-0 h-0.5 z-10 pointer-events-none",
            dropTargetClass,
          ])}
          style={{
            top:
              dropAtIndex >= items.length
                ? totalHeight - paddingBottom
                : offsets[dropAtIndex],
          }}
        />
      )}
    </div>
  );
}
