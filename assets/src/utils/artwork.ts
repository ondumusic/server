import type { ArtworkImage } from "../types";

type WithArtwork = { artwork?: ArtworkImage[] };

// For small artwork like list rows, the smallest available version.
export function artworkThumbnailUrl(
  parent?: WithArtwork | null,
): string | undefined {
  return parent?.artwork?.[0]?.url;
}

export function artworkUrl(parent?: WithArtwork | null): string | undefined {
  return parent?.artwork?.at(-1)?.url;
}

export function artworkUrls(parents: WithArtwork[]): string[] {
  return parents.flatMap(
    (parent) => parent.artwork?.map((image) => image.url) ?? [],
  );
}
