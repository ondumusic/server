import { useCallback, useState } from "react";
import { PlaylistList } from "../components/PlaylistList";
import { useDialog } from "../hooks/useDialog";
import type { UUID } from "../types";

type Result = {
  playlistId: UUID;
};

const PlaylistPicker = ({
  onClose,
}: {
  onClose: (result: Result | false) => void;
}) => {
  const [playlistId, setPlaylistId] = useState<string>();

  return (
    <div className="bg-gray-300">
      <div className="bg-sidebar-bg max-h-100 overflow-auto">
        <PlaylistList
          playlistId={playlistId}
          onChange={(playlist) => setPlaylistId(playlist.id)}
          onSubmit={(playlist) => {
            onClose({ playlistId: playlist.id });
          }}
        />
      </div>

      <div className="flex gap-2 p-2 text-md font-medium bg-sidebar-bg">
        <button
          className="w-full rounded-md cursor-pointer py-2 px-6 text-md font-medium bg-sidebar-active-bg shadow-sm text-sidebar-active-fg focus:border-0 focus:ring-0 focus:outline-0"
          type="button"
          onClick={() => onClose(false)}
        >
          Cancel
        </button>
        <button
          className="w-full rounded-md cursor-pointer py-2 px-6 text-md font-medium text-accent-500 bg-sidebar-active-bg shadow-sm focus:border-0 focus:ring-0 focus:outline-0"
          type="button"
          onClick={() => onClose(playlistId ? { playlistId } : false)}
        >
          Confirm
        </button>
      </div>
    </div>
  );
};

export function usePlaylistPicker() {
  const { showDialog, closeDialog } = useDialog();

  const renderDialog = useCallback(() => {
    return <PlaylistPicker onClose={closeDialog} />;
  }, [closeDialog]);

  const showPlaylistPicker = useCallback(async () => {
    const result = await showDialog<Result>({ renderDialog });
    if (typeof result === "boolean") return result;
    return result?.playlistId;
  }, [showDialog, renderDialog]);

  return { showPlaylistPicker };
}
