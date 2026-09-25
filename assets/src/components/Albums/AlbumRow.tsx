import { memo } from "react";
import { Marquee } from "../../components/Marquee";
import type { Album } from "../../types";
import { artworkThumbnailUrl } from "../../utils/artwork";
import { classNames } from "../../utils/classNames";

interface Props {
  album: Album;
  isSelected: boolean;
}

export const AlbumRow = memo(({ album, isSelected = false }: Props) => {
  return (
    <li
      className={classNames([
        "mx-2 px-4 rounded-md whitespace-nowrap items-center flex gap-4",
        "text-sm",
        isSelected &&
          "bg-sidebar-inactive-bg text-sidebar-inactive-fg [.selectable-list:focus_&]:bg-sidebar-active-bg [.selectable-list:focus_&]:shadow-sm [.selectable-list:focus_&]:text-sidebar-active-fg",
      ])}
    >
      <div
        className="relative w-10 h-10 aspect-square bg-cover bg-center shadow-md rounded-md bg-stone-900 flex-shrink-0"
        style={{
          contentVisibility: "auto",
          ...(artworkThumbnailUrl(album) && {
            backgroundImage: `url(${artworkThumbnailUrl(album)})`,
          }),
        }}
      />
      <div className="py-2.5 max-w-full overflow-auto">
        <Marquee delay={500} text={album.name} />
        <Marquee
          className="text-sm text-muted"
          delay={500}
          text={album?.artistName ?? ""}
        />
      </div>
    </li>
  );
});
