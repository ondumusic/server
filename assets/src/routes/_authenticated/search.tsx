import { createFileRoute } from "@tanstack/react-router";
import { EmptyView } from "../../components/EmptyView";
import { SearchResults } from "../../components/SearchResults";
import i18next from "../../i18next";
import {
  canSearch,
  type SearchResults as SearchResultsT,
  useSearch,
} from "../../library/search";

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
  const query = String(q);
  const { results, loading } = useSearch(query);

  // NOTE: The pt-[23px] is to match the header alignment with other routes
  return (
    <div className="@container h-full px-4 pt-[23px] bg-content-bg">
      <SearchContent query={query} results={results} loading={loading} />
    </div>
  );
}

function SearchContent({
  query,
  results,
  loading,
}: {
  query: string;
  results: SearchResultsT;
  loading: boolean;
}) {
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

  return <SearchResults results={results} />;
}
