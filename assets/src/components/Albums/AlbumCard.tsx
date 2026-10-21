import type { Album } from "../../types";
import { classNames } from "../../utils/classNames";
import { AlbumArtwork } from "../AlbumArtwork";

export function AlbumCard({
  album,
  isSelected,
}: {
  album: Album;
  isSelected: boolean;
}) {
  return (
    <div className="text-center w-full">
      <AlbumArtwork
        album={album}
        size="large"
        className="w-full aspect-square shadow-md rounded-md bg-stone-900"
        style={{ contentVisibility: "auto" }}
      >
        {isSelected && (
          <div className="absolute top-0 left-0 right-0 bottom-0 border-2 border-accent-400 [.selectable-list:focus_&]:border-accent-500 rounded-md bg-accent-400/20 [.selectable-list:focus_&]:bg-accent-500/30" />
        )}
      </AlbumArtwork>
      <div className="pt-2 text-xs leading-2">
        <span
          className={classNames([
            "inline-block max-w-full truncate leading-4 px-2 py-0.5",
            isSelected &&
              "rounded-md bg-accent-400 [.selectable-list:focus_&]:bg-accent-500 text-white",
          ])}
        >
          {album.name}
        </span>
        <br />
        <span
          className={classNames([
            "inline-block max-w-full truncate leading-4 px-2 py-0.5 text-muted",
            isSelected &&
              "rounded-md bg-accent-400 [.selectable-list:focus_&]:bg-accent-500 text-white",
          ])}
        >
          {album.artistName}
        </span>
      </div>
    </div>
  );
}
