import type { Album, Artist, Track } from "../../types";

// Bump this number to make sure the client reindex all records
// to create new updated search tokens.
export const searchTokensVersion = 2;

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

// Slugs are already transliterated on the server so we can include
// those as search tokens too to try and make search even more useful.
type WithSlug = { slug?: string };
type WithArtist = { artist?: WithSlug | null };

// For every store we can define which fields we want to use as search tokens.
export const searchTokens = {
  artist(artist: Pick<Artist, "name"> & WithSlug) {
    return uniqueTokens(artist.name, artist.slug);
  },

  album(album: Pick<Album, "name" | "artistName"> & WithSlug & WithArtist) {
    return uniqueTokens(
      album.name,
      album.artistName,
      album.slug,
      album.artist?.slug,
    );
  },

  track(track: Pick<Track, "name" | "artistName"> & WithArtist) {
    return uniqueTokens(track.name, track.artistName, track.artist?.slug);
  },
};
