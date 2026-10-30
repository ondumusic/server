import type { CSSProperties, PropsWithChildren } from "react";
import type { Artist } from "../types";
import { classNames } from "../utils/classNames";
import { MicrophoneIcon } from "./icons/MicrophoneIcon";

export function ArtistArtwork({
  className,
  style,
  children,
}: PropsWithChildren<{
  artist?: Artist | null;
  size: "thumbnail" | "large";
  className?: string;
  style?: CSSProperties;
}>) {
  return (
    <div
      className={classNames([
        "relative flex items-center justify-center bg-stone-200",
        className,
      ])}
      style={style}
    >
      <MicrophoneIcon className="w-2/5 h-2/5 text-stone-400/70" title="" />
      {children}
    </div>
  );
}
