import { createFileRoute, useParams } from "@tanstack/react-router";
import { Albums } from "../../components/Albums";
import { Panel } from "../../components/Panel";
import type { UUID } from "../../types";

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
  const currentAlbumId = routeParams?.albumId;

  return (
    <Panel>
      <div className="p-4 h-full overflow-auto">
        <Albums currentAlbumId={currentAlbumId} />
      </div>
    </Panel>
  );
}
