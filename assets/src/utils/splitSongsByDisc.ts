import type { Disc, Song } from "../types";

// export type SortedCreatures = { deadly: SeaCreature[], safe: SeaCreature[] };

export function splitSongsByDisc(songs: Song[]): Disc[] {
  const discs = songs.reduce<{ [key: number]: Song[] }>((result, song) => {
    if (!(song.disc in result)) result[song.disc] = [];
    result[song.disc].push(song);
    return result;
  }, {});

  return Object.keys(discs)
    .map((n) => parseInt(n, 10))
    .map((n) => ({ number: n, songs: discs[n] }));
}
