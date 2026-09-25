import type { Album } from "../types";

// For small artwork like list rows, the smallest available version.
export function artworkThumbnailUrl(album?: Album | null): string | undefined {
  return album?.artwork?.[0]?.url;
}

export function artworkUrl(album?: Album | null): string | undefined {
  return album?.artwork?.at(-1)?.url;
}
