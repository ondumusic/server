import { useEffect, useRef } from "react";
import { Link } from "react-router";
import type { AlbumArtist } from "../types";

interface Props {
  albumArtist: AlbumArtist;
  isSelected: boolean;
  scrollIntoView: boolean;
}

export function ArtistListItem({
  albumArtist,
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
      className={[isSelected ? "bg-emerald-600 text-white" : ""].join(" ")}
    >
      <Link
        to={`/artists/${albumArtist.slug}`}
        className="px-4 py-2 whitespace-nowrap items-center flex gap-2"
      >
        <div className="rounded-full bg-stone-200 aspect-square w-8 h-8"></div>
        <span className="text-ellipsis max-w-full overflow-hidden">
          {albumArtist.name}
        </span>
      </Link>
    </li>
  );
}
