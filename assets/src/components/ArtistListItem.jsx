import { useEffect, useRef } from "react";
import { Link } from "react-router";

export function ArtistListItem({
  artist,
  isSelected = false,
  scrollIntoView = false,
}) {
  const refContainer = useRef(null);

  // We ignore isSelected in the useEffect dependencies list as that value can
  // change when the user interacts with the application. By only having the
  // scrollIntoView dependency it should only trigger once, as desired.
  // biome-ignore lint/correctness/useExhaustiveDependencies(isSelected): suppress dependency isSelected
  useEffect(() => {
    if (isSelected && scrollIntoView) {
      refContainer.current.scrollIntoView({
        behavior: "instant",
        block: "center",
        container: "nearest",
      });
    }
  }, [scrollIntoView]);

  return (
    <li
      ref={refContainer}
      class={["px-4 py-2", isSelected ? "bg-emerald-600 text-white" : ""].join(
        " ",
      )}
    >
      <Link
        to={`/artist/${artist.id}`}
        className="whitespace-nowrap text-ellipsis max-w-full overflow-hidden items-center flex gap-2"
      >
        <div className="rounded-full bg-stone-200 aspect-square w-8 h-8"></div>
        <span>{artist.name}</span>
      </Link>
    </li>
  );
}
