import { albumFactory } from "@test/factory/albumFactory";
import { artistFactory } from "@test/factory/artistFactory";
import { trackFactory } from "@test/factory/trackFactory";
import { expect, test } from "vitest";
import { splitTracksByDisc } from "./splitTracksByDisc";

test("split up a list of Track[] into Disc[]", () => {
  const artist = artistFactory.build();
  const album = albumFactory.build({});
  const disc1 = [...album.tracks];

  // Create some new tracks for disc 2
  trackFactory.rewindSequence();
  const disc2 = trackFactory.buildList(5, { artist, album, disc: 2 });
  album.tracks.push(...disc2);

  expect(splitTracksByDisc(album.tracks)).toStrictEqual([
    { number: 1, tracks: disc1 },
    { number: 2, tracks: disc2 },
  ]);
});
