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
import type { Artist, UUID } from "../../types";
import { ArtistCard } from "../Artists/ArtistCard";
import { type ListItemState, SelectableList } from "../SelectableList";

interface Props {
  artists: Artist[];
}

const minCardWidth = 72;
const gapSize = 18;

export function ArtistResults({ artists }: Props) {
  const navigate = useNavigate();
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const { showToast } = useToast();
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerWidth, setContainerWidth] = useState(0);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  // Clears the selection when the results change.
  // biome-ignore lint/correctness/useExhaustiveDependencies(artists): only used to trigger a reset
  useEffect(() => {
    setSelectedIds(new Set());
  }, [artists]);

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
  const visibleArtists = useMemo(
    () => artists.slice(0, gridSize),
    [artists, gridSize],
  );

  const handleSubmit = useCallback(
    async (ids: Set<UUID>) => {
      const artist = artists.find((artist) => ids.has(artist.id));
      if (!artist) return;
      if (!(await userConfirmQueueReplace())) return;

      populateUpNext({ artistId: artist.id });
      showToast({
        message: i18next.t("toast.addedArtistToPlayNow", {
          defaultValue: "Playing {{ artistName }}",
          artistName: artist.name,
        }),
      });
    },
    [artists, populateUpNext, userConfirmQueueReplace, showToast],
  );

  const handleDoubleClick = useCallback(
    (artist: Artist) => {
      navigate({
        to: "/artists/$artistId/{-$albumId}",
        params: { artistId: artist.slug },
      });
    },
    [navigate],
  );

  const handleContextMenu = useCallback(
    (ids: Set<string>) => {
      const artist = artists.find((artist) => ids.has(artist.id));
      if (!artist) return [];

      return [
        {
          type: "item",
          key: "play",
          label: i18next.t("contextMenu.playArtist", {
            defaultValue: 'Play "{{ artist }}"',
            artist: artist.name,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ artistId: artist.id });

            showToast({
              message: i18next.t("toast.addedArtistToPlayNow", {
                defaultValue: "Playing {{ artistName }}",
                artistName: artist.name,
              }),
            });
          },
        },
        {
          type: "item",
          key: "shuffle",
          label: i18next.t("contextMenu.shuffleArtist", {
            defaultValue: 'Shuffle "{{ artist }}"',
            artist: artist.name,
          }),
          onClick: async () => {
            if (!(await userConfirmQueueReplace())) return;
            populateUpNext({ artistId: artist.id, random: true });

            showToast({
              message: i18next.t("toast.addedArtistToPlayShuffled", {
                defaultValue: "Shuffling {{ artistName }}",
                artistName: artist.name,
              }),
            });
          },
        },
      ];
    },
    [artists, userConfirmQueueReplace, populateUpNext, showToast],
  );

  const renderItem = useCallback((artist: Artist, state: ListItemState) => {
    return <ArtistCard artist={artist} isSelected={state.isSelected} />;
  }, []);

  return (
    <div className="px-2">
      <div ref={containerRef}>
        <SelectableList<Artist>
          id="artists"
          multiple={false}
          allowDrag
          allowDropFrom={[]}
          items={visibleArtists}
          gridSize={gridSize}
          gridGapSize={gapSize}
          selectedIds={selectedIds}
          onChange={setSelectedIds}
          onSubmit={handleSubmit}
          onDoubleClick={handleDoubleClick}
          onContextMenu={handleContextMenu}
          renderItem={renderItem}
        />
      </div>
    </div>
  );
}
