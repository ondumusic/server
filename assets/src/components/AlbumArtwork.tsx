import { type CSSProperties, type PropsWithChildren, useEffect } from "react";
import type { Album } from "../types";
import { artworkThumbnailUrl, artworkUrl } from "../utils/artwork";
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
  onLoad,
  children,
}: PropsWithChildren<{
  album?: Album | null;
  size: "thumbnail" | "large";
  className?: string;
  style?: CSSProperties;
  onLoad?: (image: HTMLImageElement) => void;
}>) {
  const thumbnail = artworkThumbnailUrl(album);
  const urls = (
    size === "large" ? [artworkUrl(album), thumbnail] : [thumbnail]
  ).filter((url) => !!url);
  const backgroundImage = urls.map((url) => `url(${url})`).join(", ");

  // Backgrounds have no load event, so the (top) artwork is loaded separately
  // when someone needs it (e.g. to extract its colors).
  const [topUrl] = urls;
  useEffect(() => {
    if (!topUrl || !onLoad) return;

    const image = new Image();
    image.onload = () => onLoad(image);
    image.src = topUrl;

    return () => {
      image.onload = null;
    };
  }, [topUrl, onLoad]);

  return (
    <div
      className={classNames(["relative bg-cover bg-center", className])}
      style={{ ...style, ...(backgroundImage && { backgroundImage }) }}
    >
      {children}
    </div>
  );
}
