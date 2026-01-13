import { useEffect, useMemo, useState } from "react";
import { useNavigationType, useParams } from "react-router";
import { ArtistAlbumListHeader } from "../components/ArtistAlbumListHeader";
import {
  ArtistAlbumListItem,
  type ListItem,
} from "../components/ArtistAlbumListItem";
import { Loading } from "../components/Loading";
import { SelectableList } from "../components/SelectableList";
import { useArtistQuery } from "../hooks/useArtistQuery";
import { useInfiniteArtistAlbumsQuery } from "../hooks/useInfiniteArtistAlbumsQuery";
import { usePlayer } from "../hooks/usePlayer";
import i18next from "../i18next";
import type { Album, Track, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";
import { splitTracksByDisc } from "../utils/splitTracksByDisc";
import { EmptyView } from "../views/EmptyView";

type Params = {
  artistId: UUID;
  albumId?: UUID;
};

function isAlbum(album: Album, albumId?: string): boolean {
  if (!albumId) return false;
  return album.id === albumId || album.slug === albumId;
}

export function ArtistAlbumListView() {
  const navigationType = useNavigationType();
  const { artistId, albumId } = useParams() as Params;
  const { enqueueAndPlay, enqueueNext, enqueueAfter } = usePlayer();
  const hasArtistId = !!artistId;
  const [selectedTrackIds, setSelectedTrackIds] = useState<Set<string>>(
    new Set(),
  );
  const [useSuspense, setUseSuspense] = useState(
    hasArtistId && navigationType === "POP",
  );

  useEffect(() => {
    if (useSuspense) setUseSuspense(false);
  });

  // Reset selection on artist/album change
  // biome-ignore lint/correctness/useExhaustiveDependencies(artistId): dont need it
  // biome-ignore lint/correctness/useExhaustiveDependencies(albumId): dont need it
  useEffect(() => {
    setSelectedTrackIds(new Set());
  }, [artistId, albumId]);

  const suspendUntil = albumId
    ? (entry: Album) => isAlbum(entry, albumId)
    : undefined;

  const {
    isFetching: isFetchingArtist,
    data: dataArtist,
    error: errorArtist,
  } = useArtistQuery(
    { artistId },
    {
      enabled: hasArtistId,
      suspense: useSuspense,
    },
  );

  const { isFetching, hasFirstPage, data, error } =
    useInfiniteArtistAlbumsQuery(
      {
        artistId: dataArtist?.id,
      },
      {
        enabled: !!dataArtist?.id,
        suspense: useSuspense,
        suspendUntil,
      },
    );

  const listItems = useMemo(() => {
    return paginatedMap<Album, ListItem>(data, (album, albumIndex) => {
      const tracksPerDisc = splitTracksByDisc(album.tracks);

      // Only show disc number headers if there is more than one.
      const showDiscNumbers = tracksPerDisc.length > 1;

      // Only show track artists if there is more than one.
      const showTrackArtist =
        new Set(album.tracks.map((track) => track.artist.id)).size > 1;

      // Return album item and iterate over tracks
      return [
        {
          id: album.id,
          type: "album",
          selectable: false,
          album,
          firstAlbumInList: albumIndex === 0,
        },
        ...tracksPerDisc.flatMap((disc): ListItem[] => {
          const trackCount = disc.tracks.length;

          // Convert track to TrackItem
          const tracks = disc.tracks.flatMap(
            (track, trackIndex): ListItem[] => {
              return [
                {
                  id: track.id,
                  type: "track",
                  track,
                  showTrackArtist,
                  albumTrackCount: album.tracks.length,
                  firstTrackOnDisc: trackIndex === 0,
                  lastTrackOnDisc: trackIndex === trackCount - 1,
                },
              ];
            },
          );

          // Conditionally include disc headers
          if (showDiscNumbers) {
            return [
              {
                id: `${album.id}-disc-${disc.number}`,
                type: "disc",
                selectable: false,
                disc,
              },
              ...tracks,
            ];
          } else {
            return tracks;
          }
        }),
      ];
    });
  }, [data]);

  if (!artistId)
    return (
      <EmptyView
        message={i18next.t("emptyView.noResults", {
          defaultValue: "No Results",
        })}
      />
    );

  if ((isFetching || isFetchingArtist) && !hasFirstPage) return <Loading />;
  if (errorArtist) throw errorArtist;
  if (error) throw error;
  if (!dataArtist) return;

  const currentAlbum = listItems
    .filter((item) => item.type === "album")
    .find((item) => isAlbum(item.album, albumId));

  return (
    <div className="space-y-8 mx-4 lg:mx-8 my-4 lg:my-8">
      <ArtistAlbumListHeader artist={dataArtist} />

      <SelectableList<ListItem>
        multiple
        items={listItems}
        defaultFocusId={currentAlbum?.id}
        defaultFocusType="start"
        selectedIds={selectedTrackIds}
        onChange={setSelectedTrackIds}
        onSubmit={(selectedIds) => {
          const albumTracks: Track[] = listItems
            .filter((item) => item.type === "track")
            .filter((item) => selectedIds.has(item.id))
            .map((item) => item.track);

          enqueueAndPlay(albumTracks);
        }}
        onDoubleClick={(item) => {
          if (item.type !== "track") return;

          const albumTracks = paginatedMap<Album, Track>(data, (album) => {
            if (album.id !== item.track.albumId) return [];
            return album.tracks;
          });

          enqueueAndPlay(albumTracks, item.track);
        }}
        onContextMenu={(selectedIds) => {
          const albumTracks: Track[] = listItems
            .filter((item) => item.type === "track")
            .filter((item) => selectedIds.has(item.id))
            .map((item) => item.track);

          return [
            {
              key: "play_next",
              label: i18next.t("contextMenu.playNext", {
                defaultValue: "Play Next",
                count: albumTracks.length,
              }),
              onClick() {
                enqueueNext(albumTracks);
              },
            },
            {
              key: "play_after",
              label: i18next.t("contextMenu.playAfter", {
                defaultValue: "Play After",
                count: albumTracks.length,
              }),
              onClick() {
                enqueueAfter(albumTracks);
              },
            },
          ];
        }}
        renderItem={(item, state) => (
          <ArtistAlbumListItem item={item} isSelected={state.isSelected} />
        )}
      />
    </div>
  );
}
