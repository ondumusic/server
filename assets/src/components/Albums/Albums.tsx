import { useCallback, useState } from "react";
import { Loading } from "../../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../../components/SelectableList";
import { useMediaQuery } from "../../hooks/useMediaQuery";
import { useAlbums } from "../../library";
import type { Album, UUID } from "../../types";
import { AlbumCard } from "./AlbumCard";

export function Albums({ currentAlbumId }: { currentAlbumId?: UUID }) {
  const gridSize = useMediaQuery("(width >= 48rem)") ? 5 : 2;

  const { data: albums, loading } = useAlbums();
  const [selectedIds, setSelectedIds] = useState<Set<UUID>>(new Set([]));

  const renderItem = useCallback((item: Album, state: ListItemState) => {
    return <AlbumCard album={item} isSelected={state.isSelected} />;
  }, []);

  const handleChange = useCallback((selectedIds: Set<UUID>) => {
    setSelectedIds(selectedIds);
  }, []);

  if (loading) return <Loading />;

  return (
    <SelectableList<Album>
      items={albums}
      gridSize={gridSize}
      gridGapSize={24}
      scrollOverscan={5}
      multiple={true}
      defaultFocusId={currentAlbumId}
      defaultFocusType="center"
      selectedIds={selectedIds}
      onChange={handleChange}
      renderItem={renderItem}
    />
  );
}
