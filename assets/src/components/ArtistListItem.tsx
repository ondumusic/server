import { Marquee } from "../components/Marquee";
import type { Artist } from "../types";
import { classNames } from "../utils/classNames";

interface Props {
  artist: Artist;
  isSelected: boolean;
}

export function ArtistListItem({ artist, isSelected = false }: Props) {
  return (
    <li
      className={classNames([
        "px-4 whitespace-nowrap items-center flex gap-2",
        "transition-colors duration-400",
        isSelected && "bg-accent-200 text-selected",
      ])}
    >
      <Marquee className="py-3" delay={500} text={artist.name} />
    </li>
  );
}
