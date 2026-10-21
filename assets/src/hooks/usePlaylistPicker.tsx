import { useCallback, useEffect, useState } from "react";
import { Trans } from "react-i18next";
import { playlistApi } from "../api";
import { PlaylistIcon } from "../components/icons/PlaylistIcon";
import { Playlists } from "../components/Playlists";
import { useDialog } from "../hooks/useDialog";
import { repo, sync } from "../library";
import type { Playlist, UUID } from "../types";
import { classNames } from "../utils/classNames";

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

const CreatePlaylist = ({
  onChange,
}: {
  onChange: (playlistName: string) => void;
}) => {
  return (
    <div className="text-left text-dialog-fg">
      <h3 className="font-semibold text-lg mb-6">
        <Trans i18nKey="playlistPicker.createPlaylist.title">
          Create a new playlist
        </Trans>
      </h3>

      <div>
        <label>
          <span className="block font-semibold">
            <Trans i18nKey="playlistPicker.createPlaylist.playlistName">
              Playlist Name
            </Trans>
          </span>
          <input
            type="text"
            onInput={(e) => onChange((e.target as HTMLInputElement).value)}
            className={classNames([
              "mt-2 block w-full rounded-lg focus:ring-0 sm:text-sm sm:leading-6",
              "bg-white/80 dark:bg-white/5",
              "border-zinc-400/60 focus:border-zinc-400 dark:border-white/10 dark:focus:border-white/30",
            ])}
          />
        </label>
      </div>
    </div>
  );
};

const EmptyState = ({
  onChange,
}: {
  onChange: (playlistName: string) => void;
}) => {
  const [isCreating, setIsCreating] = useState<boolean>(true);

  return (
    <div className="p-8 text-sm text-center h-full content-center text-muted">
      {isCreating ? (
        <CreatePlaylist onChange={onChange} />
      ) : (
        <>
          <PlaylistIcon title="Playlists" className="size-8 mx-auto mb-4" />
          <p className="mb-2">
            <Trans i18nKey="playlistPicker.emptyView">
              No playlists created yet.
            </Trans>
          </p>
          <button
            type="button"
            onClick={() => setIsCreating(true)}
            className="inline-flex items-center justify-center text-accent-500 font-semibold cursor-pointer hover:text-accent-800"
          >
            <Trans i18nKey="playlistPicker.createFirstPlaylist">
              Create Playlist
            </Trans>
          </button>
        </>
      )}
    </div>
  );
};

const PlaylistPicker = ({
  onClose,
}: {
  onClose: (result: Playlist | false) => void;
}) => {
  const [selectedPlaylist, selectPlaylist] = useState<Playlist | null>(
    getMostRecentPlaylist(),
  );
  const [draftPlaylist, setDraftPlaylist] = useState<string | null>();
  const [playlistCount, setPlaylistCount] = useState<number | undefined>(
    undefined,
  );

  const hasPlaylists = typeof playlistCount === "number" && playlistCount > 0;

  if (draftPlaylist) console.log(draftPlaylist);

  useEffect(() => {
    repo.count("playlists").then((count) => setPlaylistCount(count));
  }, []);

  const addToPlaylist = useCallback(async () => {
    if (!selectedPlaylist && draftPlaylist) {
      const newPlaylist = await playlistApi.createPlaylist({
        name: draftPlaylist,
      });

      await sync.pushChanges({
        playlists: [newPlaylist],
      });

      onClose(newPlaylist);

      return;
    }

    onClose(selectedPlaylist ?? false);
  }, [selectedPlaylist, draftPlaylist, onClose]);

  return (
    <div className="bg-picker-bg flex flex-col max-h-100">
      <div className="h-full min-h-42 overflow-auto">
        {!hasPlaylists && <EmptyState onChange={setDraftPlaylist} />}
        {hasPlaylists && (
          <Playlists
            playlistId={selectedPlaylist?.id}
            allowPlayback={false}
            allowDelete={false}
            onCreate={(playlist) => selectPlaylist(playlist)}
            onChange={(playlist) => selectPlaylist(playlist)}
            onSubmit={(playlist) => onClose(playlist)}
          />
        )}
      </div>

      <div className="flex flex-shrink-0 gap-2 p-2 text-md font-medium">
        <button
          className="w-full rounded-md cursor-pointer py-2 px-6 text-sm font-medium bg-black/5 hover:bg-black/10 dark:bg-white/10 dark:hover:bg-white/15 focus:border-0 focus:ring-0 focus:outline-0"
          type="button"
          onClick={() => onClose(false)}
        >
          <Trans i18nKey="playlistPicker.cancel">Cancel</Trans>
        </button>
        <button
          disabled={!selectedPlaylist && !draftPlaylist}
          className="w-full rounded-md cursor-pointer py-2 px-6 text-sm font-medium text-white bg-accent-500 hover:bg-accent-600 shadow-sm focus:border-0 focus:ring-0 focus:outline-0 disabled:bg-accent-500 disabled:opacity-40 disabled:cursor-default"
          type="button"
          onClick={addToPlaylist}
        >
          {!hasPlaylists && (
            <Trans i18nKey="playlistPicker.create">Create</Trans>
          )}
          {hasPlaylists && (
            <Trans i18nKey="playlistPicker.confirm">Confirm</Trans>
          )}
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
