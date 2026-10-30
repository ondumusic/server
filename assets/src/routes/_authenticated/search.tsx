import { createFileRoute } from "@tanstack/react-router";
import { EmptyView } from "../../components/EmptyView";
import { SearchResults } from "../../components/SearchResults";
import { useDebouncedValue } from "../../hooks/useDebouncedValue";
import i18next from "../../i18next";
import { canSearch, useSearch } from "../../library/search";

type SearchParams = {
  q?: string;
};

export const Route = createFileRoute("/_authenticated/search")({
  staticData: { view: "search" as const },
  component: SearchPage,
});

function SearchPage() {
  // the router parses 123 as number so we want to make sure we have a string
  const { q = "" } = Route.useSearch() as SearchParams;
  const query = useDebouncedValue(String(q), 150);
  const { results, loading } = useSearch(query);

  if (!canSearch(query)) {
    return (
      <EmptyView
        message={i18next.t("search.typeToSearch", {
          defaultValue: "Type to search",
        })}
      />
    );
  }

  const hasResults =
    results.artists.length > 0 ||
    results.albums.length > 0 ||
    results.tracks.length > 0;
  if (!hasResults && !loading) {
    return (
      <EmptyView
        message={i18next.t("search.noResults", {
          defaultValue: "No results for “{{ query }}”",
          query,
        })}
      />
    );
  }

  return (
    <div className="h-full mx-8 pt-4">
      <SearchResults results={results} />
    </div>
  );
}
