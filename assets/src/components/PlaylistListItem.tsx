import { memo, useEffect, useRef } from "react";
import { PlaylistFolderIcon } from "../components/icons/PlaylistFolderIcon";
import { PlaylistIcon } from "../components/icons/PlaylistIcon";
import { Marquee } from "../components/Marquee";
import i18next from "../i18next";
import type { Playlist } from "../types";
import { classNames } from "../utils/classNames";

export type ListItem = Playlist & {
  indentLevel: number;
  editing?: boolean;
  onConfirm?: (value: string) => void;
  onCancel?: () => void;
};

interface Props {
  playlist: ListItem;
  isSelected: boolean;
}

export const PlaylistListItem = memo(
  ({ playlist, isSelected = false }: Props) => {
    const inputRef = useRef<HTMLInputElement>(null);
    useEffect(() => {
      if (playlist.editing) {
        inputRef.current?.focus();
        inputRef.current?.select();
      }
    }, [playlist]);

    const placeholder = i18next.t("placeholders.newPlaylist", {
      defaultValue: "Untitled",
    });

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

        {playlist.editing === true ? (
          <input
            ref={inputRef}
            type="text"
            className="inline-block text-sm bg-transparent border-0 p-0 py-2.5 outline-0 ring-0 h-auto appearance-none w-full"
            placeholder={placeholder}
            defaultValue={playlist.name}
            onBlur={(e) => {
              const input = e.target as HTMLInputElement;

              if (playlist.onConfirm) {
                const text = input.value.trim() || placeholder;
                playlist.onConfirm(text);
              }
            }}
            onKeyDown={(e: React.KeyboardEvent) => {
              e.stopPropagation();
              const input = e.target as HTMLInputElement;

              if (e.key === "Escape") {
                if (playlist.onCancel) {
                  playlist.onCancel();
                }
              } else if (e.key === "Enter") {
                if (playlist.onConfirm) {
                  const text = input.value.trim() || placeholder;
                  playlist.onConfirm(text);
                }
              }

              return e;
            }}
            onKeyPress={(e: React.KeyboardEvent) => {
              e.stopPropagation();
              return e;
            }}
          />
        ) : (
          <Marquee className="py-2.5" delay={500} text={playlist.name} />
        )}
      </li>
    );
  },
);
