import { useCallback, useState } from "react";
import { Playlists } from "../components/Playlists";
import { useDialog } from "../hooks/useDialog";
import type { Playlist, UUID } from "../types";

const getMostRecentPlaylist = (): Playlist | null => {
  try {
    const json = localStorage.getItem("mostRecentPlaylist");
    if (!json) return null;
    return JSON.parse(json) as Playlist;
  } catch (_err) {
    return null;
  }
};

export const maybeResetPlaylistPicker = (playlistId: UUID, name?: string) => {
  const recentPlaylist = getMostRecentPlaylist();
  if (recentPlaylist?.id !== playlistId) return;

  // Update name or delete from history
  if (name) {
    localStorage.setItem(
      "mostRecentPlaylist",
      JSON.stringify({
        id: playlistId,
        name,
      }),
    );
  } else {
    localStorage.removeItem("mostRecentPlaylist");
  }
};

const PlaylistPicker = ({
  onClose,
}: {
  onClose: (result: Playlist | false) => void;
}) => {
  const [selectedPlaylist, selectPlaylist] = useState<Playlist | null>(
    getMostRecentPlaylist(),
  );

  return (
    <div className="bg-gray-200 flex flex-col max-h-100">
      <Playlists
        playlistId={selectedPlaylist?.id}
        onChange={(playlist) => selectPlaylist(playlist)}
        onSubmit={(playlist) => onClose(playlist)}
      />

      <div className="flex flex-shrink-0 gap-2 p-2 text-md font-medium">
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
          onClick={() => onClose(selectedPlaylist ?? false)}
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

  const showPlaylistPicker = useCallback(async (): Promise<
    Playlist | false
  > => {
    const result = await showDialog<Playlist>({ renderDialog });
    if (!result) return Promise.resolve(false);

    localStorage.setItem(
      "mostRecentPlaylist",
      JSON.stringify({
        id: (result as Playlist).id,
        name: (result as Playlist).name,
      }),
    );
    return result as Playlist;
  }, [showDialog, renderDialog]);

  return { showPlaylistPicker, getMostRecentPlaylist };
}
