import { createFileRoute } from "@tanstack/react-router";
import { EmptyView } from "../../components/EmptyView";
import i18next from "../../i18next";

export const Route = createFileRoute("/_authenticated/playlists/")({
  staticData: { view: "playlists" as const },
  component: PlaylistsIndex,
});

function PlaylistsIndex() {
  return (
    <EmptyView
      message={i18next.t("emptyView.noResults", {
        defaultValue: "No Results",
      })}
    />
  );
}
