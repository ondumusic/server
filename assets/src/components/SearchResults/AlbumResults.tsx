import { useNavigate } from "@tanstack/react-router";
import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { usePlayer } from "../../hooks/usePlayer";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import type { Album, UUID } from "../../types";
import { AlbumCard } from "../Albums/AlbumCard";
import { type ListItemState, SelectableList } from "../SelectableList";

interface Props {
  albums: Album[];
}

const minCardWidth = 120;
const gapSize = 18;

export function AlbumResults({ albums }: Props) {
  const navigate = useNavigate();
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const { showToast } = useToast();
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerWidth, setContainerWidth] = useState(0);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  // Clears the selection when the results change.
  // biome-ignore lint/correctness/useExhaustiveDependencies(albums): only used to trigger a reset
  useEffect(() => {
    setSelectedIds(new Set());
  }, [albums]);

  // Get the available width so we can use it to calculate the gridSize
  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    setContainerWidth(container.clientWidth);
    const observer = new ResizeObserver(() => {
      setContainerWidth(container.clientWidth);
    });
    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  // We only want to show one row of items in this grid
  const gridSize = Math.max(
    1,
    Math.floor((containerWidth + gapSize) / (minCardWidth + gapSize)),
  );
  const visibleAlbums = useMemo(
    () => albums.slice(0, gridSize),
    [albums, gridSize],
  );

  const handleSubmit = useCallback(
    async (ids: Set<UUID>) => {
      const selected = albums.filter((album) => ids.has(album.id));
      if (!selected.length) return;
      if (!(await userConfirmQueueReplace())) return;

      populateUpNext({ albumIds: selected.map((album) => album.id) });
      showToast({
        message: i18next.t("toast.addedAlbumToPlayNow", {
          defaultValue: "Playing {{ albumName }}",
          albumName: selected[0].name,
          count: selected.length,
        }),
      });
    },
    [albums, populateUpNext, userConfirmQueueReplace, showToast],
  );

  const handleDoubleClick = useCallback(
    (album: Album) => {
      navigate({ to: "/albums/$albumId", params: { albumId: album.id } });
    },
    [navigate],
  );

  const renderItem = useCallback((album: Album, state: ListItemState) => {
    return <AlbumCard album={album} isSelected={state.isSelected} />;
  }, []);

  return (
    <div className="px-2">
      <div ref={containerRef}>
        <SelectableList<Album>
          id="albums"
          multiple
          allowDrag
          allowDropFrom={[]}
          items={visibleAlbums}
          gridSize={gridSize}
          gridGapSize={gapSize}
          selectedIds={selectedIds}
          onChange={setSelectedIds}
          onSubmit={handleSubmit}
          onDoubleClick={handleDoubleClick}
          renderItem={renderItem}
        />
      </div>
    </div>
  );
}
