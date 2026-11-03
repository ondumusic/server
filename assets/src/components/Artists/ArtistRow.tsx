import { memo } from "react";
import { Marquee } from "../../components/Marquee";
import type { Artist } from "../../types";
import { classNames } from "../../utils/classNames";
import { ArtistArtwork } from "../ArtistArtwork";

interface Props {
  artist: Artist;
  isSelected: boolean;
  showPhoto: boolean;
}

export const ArtistRow = memo(
  ({ artist, isSelected = false, showPhoto }: Props) => {
    return (
      <li
        className={classNames([
          "mx-2 px-4 rounded-md whitespace-nowrap items-center flex",
          "text-sm",
          showPhoto ? "gap-3 py-1.5" : "gap-2",
          isSelected &&
            "bg-sidebar-inactive-bg text-sidebar-inactive-fg [.selectable-list:focus_&]:bg-sidebar-active-bg [.selectable-list:focus_&]:shadow-sm [.selectable-list:focus_&]:text-sidebar-active-fg",
        ])}
      >
        {showPhoto && (
          <ArtistArtwork
            artist={artist}
            size="thumbnail"
            className="size-8 rounded-full flex-shrink-0"
          />
        )}
        <Marquee
          className={showPhoto ? "py-2" : "py-2.5"}
          delay={500}
          text={artist.name}
        />
      </li>
    );
  },
);
