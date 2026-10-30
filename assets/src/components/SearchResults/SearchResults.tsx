import i18next from "../../i18next";
import type { SearchResults as SearchResultsT } from "../../library/search";
import { AlbumResults } from "./AlbumResults";
import { ArtistResults } from "./ArtistResults";
import { SectionHeader } from "./SectionHeader";
import { TrackResults } from "./TrackResults";

interface Props {
  results: SearchResultsT;
}

export function SearchResults({ results }: Props) {
  return (
    <div className="h-full overflow-auto pb-8 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      {results.artists.length > 0 && (
        <section className="pt-8 first:pt-0">
          <SectionHeader
            title={i18next.t("search.section.artists", {
              defaultValue: "Artists",
            })}
          />
          <ArtistResults artists={results.artists} />
        </section>
      )}

      {results.albums.length > 0 && (
        <section className="pt-8 first:pt-0">
          <SectionHeader
            title={i18next.t("search.section.albums", {
              defaultValue: "Albums",
            })}
          />
          <AlbumResults albums={results.albums} />
        </section>
      )}

      {results.tracks.length > 0 && (
        <section className="pt-8 first:pt-0">
          <SectionHeader
            title={i18next.t("search.section.tracks", {
              defaultValue: "Songs",
            })}
          />
          <TrackResults tracks={results.tracks} />
        </section>
      )}
    </div>
  );
}
