import { Link } from "@tanstack/react-router";
import i18next from "../../i18next";
import type { SearchResults as SearchResultsT } from "../../library/search";
import type { Album, Artist } from "../../types";
import { ResultRow } from "./ResultRow";
import { SectionHeader } from "./SectionHeader";
import { TrackResults } from "./TrackResults";

interface Props {
  results: SearchResultsT;
}

export function SearchResults({ results }: Props) {
  return (
    <div className="h-full overflow-auto pb-8 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      {results.artists.length > 0 && (
        <section>
          <SectionHeader
            title={i18next.t("search.section.artists", {
              defaultValue: "Artists",
            })}
          />
          <ArtistResults artists={results.artists} />
        </section>
      )}

      {results.albums.length > 0 && (
        <section>
          <SectionHeader
            title={i18next.t("search.section.albums", {
              defaultValue: "Albums",
            })}
          />
          <AlbumResults albums={results.albums} />
        </section>
      )}

      {results.tracks.length > 0 && (
        <section>
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

// these will be replaced later, doing one at a time starting with tracks
function ArtistResults({ artists }: { artists: Artist[] }) {
  return (
    <ul>
      {artists.map((artist) => (
        <li key={artist.id}>
          <Link
            to="/artists/$artistId/{-$albumId}"
            params={{ artistId: artist.slug }}
            className="block"
          >
            <ResultRow title={artist.name} />
          </Link>
        </li>
      ))}
    </ul>
  );
}

function AlbumResults({ albums }: { albums: Album[] }) {
  return (
    <ul>
      {albums.map((album) => (
        <li key={album.id}>
          <Link
            to="/albums/$albumId"
            params={{ albumId: album.id }}
            className="block"
          >
            <ResultRow title={album.name} subtitle={album.artistName} />
          </Link>
        </li>
      ))}
    </ul>
  );
}
