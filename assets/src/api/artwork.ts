// This limit is defined in the server module `Ondu.Artwork`.
export const maxArtworkSizeMB = 25;
export const maxArtworkSize = maxArtworkSizeMB * 1024 * 1024;

export type ArtworkError = { error: string };
export type ArtworkResult<T> = T | ArtworkError;

export function isArtworkError<T extends object>(
  result: ArtworkResult<T>,
): result is ArtworkError {
  return "error" in result;
}
