import { Link } from "@tanstack/react-router";
import { usePlayer } from "../../hooks/usePlayer";
import type { SearchResults as SearchResultsT } from "../../library/search";
import type { Track } from "../../types";
import { ResultRow } from "./ResultRow";

interface Props {
  results: SearchResultsT;
}

export function SearchResults({ results }: Props) {
  const { enqueueAndPlay, userConfirmQueueReplace } = usePlayer();

  async function playTrack(track: Track) {
    if (!(await userConfirmQueueReplace())) return;
    enqueueAndPlay([{ track }]);
  }

  return (
    <ul className="h-full overflow-auto pb-8">
      {results.artists.map((artist) => (
        <li key={artist.id}>
          <Link
            to="/artists/$artistId/{-$albumId}"
            params={{ artistId: artist.slug }}
            className="block"
          >
            <ResultRow title={artist.name} subtitle="Artist" />
          </Link>
        </li>
      ))}

      {results.albums.map((album) => (
        <li key={album.id}>
          <Link
            to="/albums/$albumId"
            params={{ albumId: album.id }}
            className="block"
          >
            <ResultRow
              title={album.name}
              subtitle={`Album / ${album.artistName}`}
            />
          </Link>
        </li>
      ))}

      {results.tracks.map((track) => (
        <li key={track.id}>
          <button
            type="button"
            className="block w-full text-left"
            onClick={() => playTrack(track)}
          >
            <ResultRow
              title={track.name}
              subtitle={`Album / ${track.artistName} / ${track.albumName}`}
            />
          </button>
        </li>
      ))}
    </ul>
  );
}
