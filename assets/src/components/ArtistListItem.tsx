import { useEffect, useRef } from "react";
import { Link } from "react-router";
import { Marquee } from "../components/Marquee";
import type { Artist } from "../types";
import { classNames } from "../utils/classNames";

interface Props {
  artist: Artist;
  isSelected: boolean;
  scrollIntoView: boolean;
}

export function ArtistListItem({
  artist,
  isSelected = false,
  scrollIntoView = false,
}: Props) {
  const refContainer = useRef<HTMLLIElement>(null);

  // We ignore isSelected in the useEffect dependencies list as that value can
  // change when the user interacts with the application. By only having the
  // scrollIntoView dependency it should only trigger once, as desired.
  // biome-ignore lint/correctness/useExhaustiveDependencies(isSelected): suppress dependency isSelected
  useEffect(() => {
    if (isSelected && scrollIntoView) {
      refContainer.current?.scrollIntoView({
        behavior: "instant",
        block: "center",
      });
    }
  }, [scrollIntoView]);

  return (
    <li
      ref={refContainer}
      className={classNames([
        "transition-colors",
        isSelected && "bg-accent-200 text-selected",
      ])}
    >
      <Link
        to={`/artists/${artist.slug}`}
        className="px-4 whitespace-nowrap items-center flex gap-2"
      >
        <Marquee className="py-3" delay={500} text={artist.name} />
      </Link>
    </li>
  );
}
