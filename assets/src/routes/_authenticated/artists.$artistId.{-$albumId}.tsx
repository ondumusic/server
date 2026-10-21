import {
  createFileRoute,
  Navigate,
  notFound,
  useRouter,
} from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Artist } from "../../components/Artist";
import { EmptyView } from "../../components/EmptyView";
import { Loading } from "../../components/Loading";
import i18next from "../../i18next";
import { queryArtist, useArtistAlbums } from "../../library";
import type { UUID } from "../../types";

export const Route = createFileRoute(
  "/_authenticated/artists/$artistId/{-$albumId}",
)({
  async loader({ params: { artistId } }: { params: { artistId?: UUID } }) {
    if (!artistId) return;
    const artist = await queryArtist(artistId);
    if (!artist) throw notFound();
    return artist;
  },
  staticData: { view: "artists" as const },
  component: ArtistDetail,
  notFoundComponent: () => <Navigate to="/artists" />,
});

type Params = {
  artistId: UUID;
  albumId?: UUID;
};

function ArtistDetail() {
  const { artistId, albumId } = Route.useParams() as Params;
  const router = useRouter();
  const isPopNavigation = router.history.location.state?.isBackForward;
  // const { data: artist } = useArtist(artistId);
  const artist = Route.useLoaderData();
  const hasArtistId = !!artistId;

  const [useSuspense, setUseSuspense] = useState(
    hasArtistId && isPopNavigation,
  );

  useEffect(() => {
    if (useSuspense) setUseSuspense(false);
  });

  const {
    data: albums,
    error,
    loading: isFetching,
  } = useArtistAlbums(artist?.id);

  if (!artistId)
    return (
      <EmptyView
        message={i18next.t("emptyView.selectArtist", {
          defaultValue: "Select an artist",
        })}
      />
    );

  if (isFetching) return <Loading />;
  if (error) throw error;
  if (!artist) return;

  return (
    <div className="h-full mx-4 lg:mx-8">
      <Artist artist={artist} albums={albums} currentAlbumId={albumId} />
    </div>
  );
}
