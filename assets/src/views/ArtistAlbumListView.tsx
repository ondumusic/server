import { useEffect, useState } from "react";
import { useNavigationType, useParams } from "react-router";
import { ArtistAlbumListHeader } from "../components/ArtistAlbumListHeader";
import { ArtistAlbumListItem } from "../components/ArtistAlbumListItem";
import { Loading } from "../components/Loading";
import { useArtistQuery } from "../hooks/useArtistQuery";
import { useInfiniteArtistAlbumsQuery } from "../hooks/useInfiniteArtistAlbumsQuery";
import i18next from "../i18next";
import type { Album, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";
import { EmptyView } from "../views/EmptyView";

type Params = { artistId: UUID };

export function ArtistAlbumListView() {
  const navigationType = useNavigationType();
  const { artistId } = useParams() as Params;
  const hasArtistId = !!artistId;
  const [useSuspense, setUseSuspense] = useState(
    hasArtistId && navigationType === "POP",
  );

  useEffect(() => {
    if (useSuspense) setUseSuspense(false);
  });

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
      },
    );

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

  return (
    <div className="space-y-8 mx-8 my-8">
      <ArtistAlbumListHeader artist={dataArtist} />
      <div className="space-y-16">
        {paginatedMap<Album>(data, (album) => (
          <ArtistAlbumListItem
            key={album.id}
            artist={dataArtist}
            album={album}
          />
        ))}
      </div>
    </div>
  );
}
