import type { CSSProperties, PropsWithChildren } from "react";
import type { Album } from "../types";
import { artworkThumbnailUrl, artworkUrl } from "../utils/artwork";
import { artworkLayers } from "../utils/artworkLayers";
import { classNames } from "../utils/classNames";

// Shows the artwork of an album as css background, the className should set
// the size and a placeholder background for albums without artwork.
//
// - thumbnail: for small artwork (e.g. list rows), only the thumbnail.
// - large: only thumbnails are prewarmed in the artwork cache, so the large
//   artwork is layered on top of the thumbnail which shows until it is loaded.
export function AlbumArtwork({
  album,
  size,
  className,
  style,
  children,
}: PropsWithChildren<{
  album?: Album | null;
  size: "thumbnail" | "large";
  className?: string;
  style?: CSSProperties;
}>) {
  const thumbnail = artworkThumbnailUrl(album);
  const urls = (
    size === "large" ? [artworkUrl(album), thumbnail] : [thumbnail]
  ).filter((url): url is string => !!url);

  return (
    <div
      className={classNames(["relative", className])}
      style={{ ...style, ...artworkLayers(urls) }}
    >
      {children}
    </div>
  );
}
