import { useNavigate } from "@tanstack/react-router";
import { type PropsWithChildren, useCallback, useMemo } from "react";
import { ArtistListItem } from "../components/ArtistListItem";
import { Loading } from "../components/Loading";
import {
  type ListItemState,
  SelectableList,
} from "../components/SelectableList";
import { useInfiniteArtistsQuery } from "../hooks/useInfiniteArtistsQuery";
import { usePlayer } from "../hooks/usePlayer";
import { useQueue } from "../hooks/useQueue";
import { api } from "../services/api";
import type { Album, Artist, Page, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

type Request = undefined;
type Response<T> = Page<T>;

function isArtist(artist: Artist, artistId: string): boolean {
  return artist.id === artistId || artist.slug === artistId;
}

export function ArtistList({
  artistId,
}: PropsWithChildren<{
  artistId?: UUID;
}>) {
  const navigate = useNavigate();
  const { enqueueAfter, userConfirmQueueReplace } = usePlayer();
  const { replaceQueue } = useQueue();

  const suspendUntil = artistId
    ? (entry: Artist) => isArtist(entry, artistId)
    : undefined;

  const { hasFirstPage, data } = useInfiniteArtistsQuery({
    suspense: true,
    suspendUntil,
  });

  const listItems = useMemo(
    () => paginatedMap<Artist, Artist>(data, (artist) => artist),
    [data],
  );

  const populateUpNext = useCallback(
    async (artist: Artist, page: number = 1) => {
      const response = await api.get<Request, Response<Album>>(
        `/artists/${artist.id}/albums`,
        {
          page: page.toString(),
        },
      );

      let firstAlbum = true;

      for (const album of response.entries) {
        if (firstAlbum && page === 1) {
          replaceQueue(album.tracks);
        } else {
          enqueueAfter(album.tracks);
        }

        firstAlbum = false;
      }

      // Get more.
      if (response.pageNumber < response.totalPages) {
        populateUpNext(artist, response.pageNumber + 1);
      }
    },
    [replaceQueue, enqueueAfter],
  );

  const onTypeMatch = useCallback((item: Artist, query: string) => {
    const matcher = new RegExp(`^${query.replace(/\s+/g, "")}`, "iu");
    const name = item.name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/\s+/g, "");

    return name.match(matcher) !== null;
  }, []);

  const onChange = useCallback(
    (selectedIds: Set<string>) => {
      const artist = listItems.find((artist) => selectedIds.has(artist.id));
      if (artist)
        navigate({
          to: `/artists/${artist.slug}`,
          params: { artistId: artist.id },
        });
    },
    [listItems, navigate],
  );

  const onDoubleClick = useCallback(
    async (artist: Artist) => {
      if (!(await userConfirmQueueReplace())) return;
      populateUpNext(artist);
    },
    [userConfirmQueueReplace, populateUpNext],
  );

  const onSubmit = useCallback(
    async (selectedIds: Set<string>) => {
      if (!(await userConfirmQueueReplace())) return;
      const artist = listItems.find((artist) => selectedIds.has(artist.id));
      if (!artist) return;
      populateUpNext(artist);
    },
    [listItems, userConfirmQueueReplace, populateUpNext],
  );

  const renderItem = useCallback(
    (artist: Artist, state: ListItemState) => (
      <ArtistListItem isSelected={state.isSelected} artist={artist} />
    ),
    [],
  );

  if (!hasFirstPage) return <Loading />;

  const currentArtist = artistId
    ? listItems.find((artist) => isArtist(artist, artistId))
    : undefined;

  return (
    <SelectableList<Artist>
      multiple={false}
      items={listItems}
      defaultFocusId={currentArtist?.id}
      onTypeMatch={onTypeMatch}
      defaultFocusType="center"
      selectedIds={currentArtist ? new Set([currentArtist.id]) : new Set([])}
      onContextMenu={() => []}
      onChange={onChange}
      onSubmit={onSubmit}
      onDoubleClick={onDoubleClick}
      renderItem={renderItem}
    />
  );
}
