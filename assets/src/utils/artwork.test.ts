import { albumFactory } from "@test/factory/albumFactory";
import { expect, test } from "vitest";
import { artworkThumbnailUrl, artworkUrl } from "./artwork";

test("picks the smallest and largest artwork", () => {
  const album = albumFactory.build({
    artwork: [
      { url: "/artwork/1/thumbnail.jpg", width: 128, height: 128 },
      { url: "/artwork/1/large.jpg", width: 450, height: 450 },
    ],
  });

  expect(artworkThumbnailUrl(album)).toBe("/artwork/1/thumbnail.jpg");
  expect(artworkUrl(album)).toBe("/artwork/1/large.jpg");
});

test("returns undefined without artwork", () => {
  expect(artworkThumbnailUrl(albumFactory.build({ artwork: [] }))).toBe(
    undefined,
  );
  expect(artworkUrl(albumFactory.build({ artwork: undefined }))).toBe(
    undefined,
  );
  expect(artworkUrl(undefined)).toBe(undefined);
});
