import { createFileRoute } from "@tanstack/react-router";
import { EmptyView } from "../../components/EmptyView";
import i18next from "../../i18next";

export const Route = createFileRoute("/_authenticated/artists/")({
  staticData: { view: "artists" as const },
  component: ArtistsIndex,
});

function ArtistsIndex() {
  return (
    <EmptyView
      message={i18next.t("emptyView.noResults", {
        defaultValue: "No Results",
      })}
    />
  );
}
