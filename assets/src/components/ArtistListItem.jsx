import { Link } from "react-router";

export function ArtistListItem({ artist, isSelected = false }) {
  return (
    <li
      class={["px-4 py-2", isSelected ? "bg-emerald-600 text-white" : ""].join(
        " ",
      )}
    >
      <Link
        to={`/artist/${artist.id}`}
        class="whitespace-nowrap text-ellipsis max-w-full overflow-hidden items-center flex gap-2"
      >
        <div class="rounded-full bg-stone-200 aspect-square w-8 h-8"></div>
        <span>{artist.name}</span>
      </Link>
    </li>
  );
}
