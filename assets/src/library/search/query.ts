import type { Album, Artist, Track } from "../../types";
import { useStoreQuery } from "../hooks";
import { repo } from "../repo";
import { normalizeSearchText, tokenize } from "./tokens";

export type SearchResults = {
  artists: Artist[];
  albums: Album[];
  tracks: Track[];
};

interface PrefixQuery {
  whereIndex: ["by_searchToken", "between", string, string];
  having: { searchTokens: (tokens: string[] | undefined) => boolean };
}

const minLookupLength = 2;

const limits = {
  artists: 5,
  albums: 5,
  tracks: 10,
};

export function canSearch(query: string) {
  return tokenize(query).some((token) => token.length >= minLookupLength);
}

// Search functions
async function searchArtists(query: string) {
  if (!canSearch(query)) return [];
  const rows = await repo.query<Artist>("artists", prefixQuery(query));
  return topResults(rows, query, limits.artists);
}

async function searchAlbums(query: string) {
  if (!canSearch(query)) return [];
  const rows = await repo.query<Album>("albums", prefixQuery(query));
  return topResults(rows, query, limits.albums);
}

async function searchTracks(query: string) {
  if (!canSearch(query)) return [];
  const rows = await repo.query<Track>("tracks", prefixQuery(query));
  return topResults(rows, query, limits.tracks);
}

export function useSearch(query: string) {
  const artists = useStoreQuery("artists", () => searchArtists(query), [query]);
  const albums = useStoreQuery("albums", () => searchAlbums(query), [query]);
  const tracks = useStoreQuery("tracks", () => searchTracks(query), [query]);

  const results: SearchResults = {
    artists: artists.data,
    albums: albums.data,
    tracks: tracks.data,
  };

  const loading = artists.loading || albums.loading || tracks.loading;

  return { results, loading };
}

// We can only lookup one word in the index, so we use the longest
// word and then check the other words in-memory.
function prefixQuery(query: string): PrefixQuery {
  const queryTokens = tokenize(query);
  const [longest] = [...queryTokens].sort((a, b) => b.length - a.length);

  return {
    // Because of how IndexedDB ranges work we match between the word and
    // the word with the highest utf-16 code (`\uffff`) so it should return
    // every token starting with the word. Might be better ways to do this
    // but it's a first version of search so let's see how it evolves.
    whereIndex: ["by_searchToken", "between", longest, `${longest}\uffff`],
    having: { searchTokens: (tokens) => matchesAll(tokens, queryTokens) },
  };
}

function matchesAll(tokens: string[] | undefined, queryTokens: string[]) {
  if (!tokens) return false;
  return queryTokens.every((q) => tokens.some((t) => t.startsWith(q)));
}

// A simple way to try and get the top results by removing duplicates
// and sorting results that start with query to the top.
function topResults<T extends { id: string; name: string }>(
  rows: T[],
  query: string,
  limit: number,
) {
  const unique = [...new Map(rows.map((row) => [row.id, row])).values()];
  const normalizedQuery = normalizeSearchText(query).trim();
  unique.sort((a, b) => compareResults(a.name, b.name, normalizedQuery));
  return unique.slice(0, limit);
}

// Sort results by starts with query, then alphabetical
function compareResults(a: string, b: string, normalizedQuery: string) {
  const aStarts = normalizeSearchText(a).startsWith(normalizedQuery);
  const bStarts = normalizeSearchText(b).startsWith(normalizedQuery);
  if (aStarts !== bStarts) return aStarts ? -1 : 1;
  return a.localeCompare(b);
}
