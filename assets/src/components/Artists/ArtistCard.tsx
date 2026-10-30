import type { Artist } from "../../types";
import { classNames } from "../../utils/classNames";
import { ArtistArtwork } from "../ArtistArtwork";

export function ArtistCard({
  artist,
  isSelected,
}: {
  artist: Artist;
  isSelected: boolean;
}) {
  return (
    <div className="text-center w-full">
      <ArtistArtwork
        artist={artist}
        size="large"
        className="w-full aspect-square rounded-full"
        style={{ contentVisibility: "auto" }}
      >
        {isSelected && (
          <div className="absolute top-0 left-0 right-0 bottom-0 border-2 border-accent-400 [.selectable-list:focus_&]:border-accent-500 rounded-full bg-accent-400/20 [.selectable-list:focus_&]:bg-accent-500/30" />
        )}
      </ArtistArtwork>
      <div className="pt-2 text-[11px] leading-2">
        <span
          className={classNames([
            "inline-block max-w-full truncate leading-4 px-1 py-0.5",
            isSelected &&
              "rounded-md bg-accent-400 [.selectable-list:focus_&]:bg-accent-500 text-white",
          ])}
        >
          {artist.name}
        </span>
      </div>
    </div>
  );
}
