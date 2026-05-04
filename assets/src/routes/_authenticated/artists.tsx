import { createFileRoute, Outlet, useParams } from "@tanstack/react-router";
import { useCallback } from "react";
import { ArtistList } from "../../components/ArtistList";
import { Panel } from "../../components/Panel";
import type { UUID } from "../../types";

export const Route = createFileRoute("/_authenticated/artists")({
  staticData: { view: "artists" as const },
  component: Artists,
});

type Params = {
  artistId: UUID;
};

function Artists() {
  const routeParams = useParams({
    from: "/_authenticated/artists/$artistId/{-$albumId}",
    shouldThrow: false,
  }) as Params;

  const artistId = routeParams?.artistId;

  const renderSidebar = useCallback(() => {
    return <ArtistList artistId={artistId} />;
  }, [artistId]);

  return (
    <Panel renderSidebar={renderSidebar} mobileShowSidebar={!artistId}>
      <Outlet />
    </Panel>
  );
}
