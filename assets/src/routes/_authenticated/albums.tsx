import {
  createFileRoute,
  Outlet,
  useNavigate,
  useParams,
} from "@tanstack/react-router";
import { useCallback } from "react";
import { Albums } from "../../components/Albums";
import { Panel } from "../../components/Panel";
import type { Album, UUID } from "../../types";

export const Route = createFileRoute("/_authenticated/albums")({
  staticData: { view: "albums" as const },
  component: AlbumsLayout,
});

type Params = {
  albumId?: UUID;
};

function AlbumsLayout() {
  const routeParams = useParams({
    from: "/_authenticated/albums/$albumId",
    shouldThrow: false,
  }) as Params;
  const navigate = useNavigate();
  const currentAlbumId = routeParams?.albumId;

  const handleGotoAlbumDetails = useCallback(
    (album: Album) => {
      navigate({
        to: `/albums/${album.id}`,
        params: { albumId: album.id },
      });
    },
    [navigate],
  );

  const randerSidebar = useCallback(() => {
    if (!currentAlbumId) return;
    return (
      <Albums
        style="list"
        currentAlbumId={currentAlbumId}
        gotoAlbumDetails={handleGotoAlbumDetails}
      />
    );
  }, [currentAlbumId, handleGotoAlbumDetails]);

  return (
    <Panel renderSidebar={randerSidebar}>
      <div className="p-4 h-full overflow-auto">
        {currentAlbumId ? (
          <Outlet />
        ) : (
          <Albums
            style="grid"
            currentAlbumId={currentAlbumId}
            gotoAlbumDetails={handleGotoAlbumDetails}
          />
        )}
      </div>
    </Panel>
  );
}
