import type { Album, Artist, Track } from "../../types";

// Bump this number to make sure the client reindex all records
// to create new updated search tokens.
export const searchTokensVersion = 1;

// Normalises text, so for example `Björk` becomes `bjork`
export function normalizeSearchText(text: string): string {
  return (
    text
      // This splits accented letters into the letter and accent separately
      // so we can remove the accent in the next step
      .normalize("NFD")
      .replace(/\p{Diacritic}/gu, "")
      // for example make `don't` appear as `dont`
      .replace(/['’]/g, "")
      .toLowerCase()
  );
}

// Splits text into an array of normalised words, so for example
// "AC/DC – Back In Black" becomes ["ac", "dc", "back", "in", "black"]
export function tokenize(text: string | undefined): string[] {
  if (!text) return [];

  return normalizeSearchText(text)
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean);
}

function uniqueTokens(...texts: (string | undefined)[]): string[] {
  return [...new Set(texts.flatMap(tokenize))];
}

// For every store we can define which fields we want to use as search tokens.
export const searchTokens = {
  artist(artist: Pick<Artist, "name">) {
    return uniqueTokens(artist.name);
  },

  album(album: Pick<Album, "name" | "artistName">) {
    return uniqueTokens(album.name, album.artistName);
  },

  track(track: Pick<Track, "name" | "artistName">) {
    return uniqueTokens(track.name, track.artistName);
  },
};
