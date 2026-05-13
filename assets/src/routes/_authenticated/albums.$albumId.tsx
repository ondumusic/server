import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/albums/$albumId")({
  staticData: { view: "albums" as const },
  component: AlbumsDetail,
});

function AlbumsDetail() {
  return <div className="">AlbumDetailView</div>;
}
