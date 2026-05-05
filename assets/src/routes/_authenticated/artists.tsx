import {
  createFileRoute,
  Outlet,
  useNavigate,
  useParams,
} from "@tanstack/react-router";
import { useCallback } from "react";
import { Artists } from "../../components/Artists";
import { Panel } from "../../components/Panel";
import { usePlayer } from "../../hooks/usePlayer";
import type { Artist, UUID } from "../../types";

export const Route = createFileRoute("/_authenticated/artists")({
  staticData: { view: "artists" as const },
  component: ArtistsLayout,
});

type Params = {
  artistId: UUID;
};

function ArtistsLayout() {
  const navigate = useNavigate();
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();
  const routeParams = useParams({
    from: "/_authenticated/artists/$artistId/{-$albumId}",
    shouldThrow: false,
  }) as Params;

  const artistId = routeParams?.artistId;

  const handleSubmit = useCallback(
    async (artist: Artist) => {
      if (!(await userConfirmQueueReplace())) return;
      populateUpNext({ artistId: artist.id });
    },
    [userConfirmQueueReplace, populateUpNext],
  );

  const handleChange = useCallback(
    async (artist: Artist) => {
      navigate({
        to: `/artists/${artist.slug}`,
        params: { artistId: artist.id },
      });
    },
    [navigate],
  );

  const renderSidebar = useCallback(() => {
    return (
      <Artists
        artistId={artistId}
        onChange={handleChange}
        onSubmit={handleSubmit}
      />
    );
  }, [artistId, handleChange, handleSubmit]);

  return (
    <Panel renderSidebar={renderSidebar} mobileShowSidebar={!artistId}>
      <Outlet />
    </Panel>
  );
}
