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
        "mx-2 px-4 rounded-md whitespace-nowrap items-center flex gap-2",
        "text-sm",
        isSelected &&
          "bg-sidebar-inactive-bg text-sidebar-inactive-fg [.selectable-list:focus_&]:bg-sidebar-active-bg [.selectable-list:focus_&]:shadow-sm [.selectable-list:focus_&]:text-sidebar-active-fg",
      ])}
    >
      <Marquee className="py-2.5" delay={500} text={artist.name} />
    </li>
  );
});
