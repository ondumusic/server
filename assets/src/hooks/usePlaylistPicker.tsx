import { useCallback } from "react";
import { PlaylistList } from "../components/PlaylistList";
import { useDialog } from "../hooks/useDialog";

export function usePlaylistPicker() {
  const { showDialog } = useDialog();

  const renderDialog = useCallback((dismiss: (result: boolean) => void) => {
    return (
      <div>
        <div className="py-2 px-6 text-md font-medium border-b border-panel-fg-divider">
          Select a Playlist
        </div>
        <PlaylistList />
        <div className="flex text-md font-medium border-t border-panel-fg-divider divide-x-1 divide-panel-fg-divider">
          <button
            className="w-full cursor-pointer py-2 px-6 text-md font-medium text-muted hover:text-black"
            type="button"
            onClick={() => dismiss(false)}
          >
            Cancel
          </button>
          <button
            className="w-full cursor-pointer py-2 px-6 text-md font-medium text-accent-500 hover:text-black focus:border-0 focus:ring-0 focus:outline-0"
            type="button"
            onClick={() => dismiss(true)}
          >
            Confirm
          </button>
        </div>
      </div>
    );
  }, []);

  const showPlaylistPicker = useCallback(async () => {
    const completed = await showDialog({ renderDialog });

    if (completed === true) return "abc";
    else return null;
  }, [showDialog, renderDialog]);

  return { showPlaylistPicker };
}
