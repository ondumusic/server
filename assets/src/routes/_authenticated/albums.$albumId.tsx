import { createFileRoute, Navigate, notFound } from "@tanstack/react-router";
import { Album } from "../../components/Album";
import { Loading } from "../../components/Loading";
import { queryAlbum, useTracks } from "../../library";
import type { UUID } from "../../types";

type Params = {
  albumId: UUID;
};

export const Route = createFileRoute("/_authenticated/albums/$albumId")({
  async loader({ params: { albumId } }: { params: Params }) {
    if (!albumId) return;
    const album = await queryAlbum(albumId);
    if (!album) throw notFound();
    return album;
  },
  staticData: { view: "albums" as const },
  component: AlbumsDetail,
  notFoundComponent: () => <Navigate to="/albums" />,
});

function AlbumsDetail() {
  const { albumId } = Route.useParams() as Params;
  const album = Route.useLoaderData();
  const { data: tracks, loading, error } = useTracks({ albumId });

  if (loading) return <Loading />;
  if (error) throw error;
  if (!album) return;

  return (
    <div className="h-full mx-8">
      <Album album={album} tracks={tracks} />
    </div>
  );
}
