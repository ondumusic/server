import { memo } from "react";
import { PlaylistFolderIcon } from "../components/icons/PlaylistFolderIcon";
import { PlaylistIcon } from "../components/icons/PlaylistIcon";
import { Marquee } from "../components/Marquee";
import type { Playlist } from "../types";
import { classNames } from "../utils/classNames";

export type ListItem = Playlist & {
  indentLevel: number;
};

interface Props {
  playlist: ListItem;
  isSelected: boolean;
}

export const PlaylistListItem = memo(
  ({ playlist, isSelected = false }: Props) => {
    return (
      <li
        className={classNames([
          "mx-2 px-4 rounded-md whitespace-nowrap items-center flex gap-2",
          "text-sm",
          isSelected &&
            "bg-sidebar-inactive-bg text-sidebar-inactive-fg [.selectable-list:focus_&]:bg-sidebar-active-bg [.selectable-list:focus_&]:shadow-sm [.selectable-list:focus_&]:text-sidebar-active-fg",
        ])}
      >
        {playlist.indentLevel > 0 && (
          <div
            style={{
              marginRight: playlist.indentLevel * 18,
            }}
          ></div>
        )}

        {playlist.isFolder ? (
          <PlaylistFolderIcon title={playlist.name} className="size-5" />
        ) : (
          <PlaylistIcon title={playlist.name} className="size-5" />
        )}
        <Marquee className="py-2.5" delay={500} text={playlist.name} />
      </li>
    );
  },
);
