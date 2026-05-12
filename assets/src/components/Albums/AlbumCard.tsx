import type { Album } from "../../types";
import { classNames } from "../../utils/classNames";

export function AlbumCard({
  album,
  isSelected,
}: {
  album: Album;
  isSelected: boolean;
}) {
  return (
    <div className="text-center w-full">
      <div
        className="relative w-full aspect-square bg-cover bg-center shadow-md rounded-md bg-stone-900"
        style={{
          contentVisibility: "auto",
          ...(album.artworkUrl && {
            backgroundImage: `url(${album.artworkUrl})`,
          }),
        }}
      >
        {isSelected && (
          <div className="absolute top-0 left-0 right-0 bottom-0 border-2 border-blue-500 rounded-md bg-blue-500/30" />
        )}
      </div>
      <div className="pt-1.5 text-xs leading-2">
        <span
          className={classNames([
            "inline-block max-w-full truncate leading-4 px-2 py-0.5",
            isSelected && "rounded-md bg-blue-500 text-white",
          ])}
        >
          {album.name}
        </span>
        <br />
        <span
          className={classNames([
            "inline-block max-w-full truncate leading-4 px-2 py-0.5 text-muted",
            isSelected && "rounded-md bg-blue-500 text-white",
          ])}
        >
          {album.artistName}
        </span>
      </div>
    </div>
  );
}
