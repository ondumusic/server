import { memo } from "react";
import { Marquee } from "../components/Marquee";
import type { Artist } from "../types";
import { classNames } from "../utils/classNames";

interface Props {
  artist: Artist;
  isSelected: boolean;
}

export const ArtistListItem = memo(({ artist, isSelected = false }: Props) => {
  return (
    <li
      className={classNames([
        "px-4 whitespace-nowrap items-center flex gap-2",
        "transition-colors duration-400",
        isSelected &&
          "bg-accent-400 [.selectable-list:focus_&]:bg-accent-500 text-white",
      ])}
    >
      <Marquee className="py-3" delay={500} text={artist.name} />
    </li>
  );
});
