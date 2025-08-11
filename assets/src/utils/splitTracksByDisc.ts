import type { Disc, Track } from "../types";

export function splitTracksByDisc(tracks: Track[]): Disc[] {
  const discs = tracks.reduce<{ [key: number]: Track[] }>((result, track) => {
    if (!(track.disc in result)) result[track.disc] = [];
    result[track.disc].push(track);
    return result;
  }, {});

  return Object.keys(discs)
    .map((n) => parseInt(n, 10))
    .map((n) => ({ number: n, tracks: discs[n] }));
}
