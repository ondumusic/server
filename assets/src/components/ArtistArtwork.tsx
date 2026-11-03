import type { CSSProperties, PropsWithChildren } from "react";
import type { Artist } from "../types";
import { artworkThumbnailUrl, artworkUrl } from "../utils/artwork";
import { classNames } from "../utils/classNames";
import { MicrophoneIcon } from "./icons/MicrophoneIcon";

export function ArtistArtwork({
  artist,
  size,
  className,
  style,
  children,
}: PropsWithChildren<{
  artist?: Artist | null;
  size: "thumbnail" | "large";
  className?: string;
  style?: CSSProperties;
}>) {
  const thumbnail = artworkThumbnailUrl(artist);
  const urls = (
    size === "large" ? [artworkUrl(artist), thumbnail] : [thumbnail]
  ).filter((url) => !!url);
  const backgroundImage = urls.map((url) => `url(${url})`).join(", ");

  return (
    <div
      className={classNames([
        "relative flex items-center justify-center bg-stone-200 bg-cover bg-center",
        className,
      ])}
      style={{ ...style, ...(backgroundImage && { backgroundImage }) }}
    >
      {!backgroundImage && (
        <MicrophoneIcon className="w-2/5 h-2/5 text-stone-400/70" title="" />
      )}
      {children}
    </div>
  );
}
