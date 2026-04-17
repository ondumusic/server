import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
} from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { useDialog } from "../hooks/useDialog";
import { useQueue } from "../hooks/useQueue";
import i18next from "../i18next";
import { queryTracks } from "../library";
import type { Track, UUID } from "../types";

interface PopulateInput {
  artistId?: UUID;
  albumId?: UUID;
  random?: boolean;
}

export interface PlayerContext {
  // Queue management
  enqueueAndPlay(tracks: Track[], startWithTrack?: Track): void;
  enqueueNext(tracks: Track[]): void;
  enqueueAfter(tracks: Track[]): void;
  populateUpNext(input: PopulateInput): void;
  userConfirmQueueReplace(): Promise<boolean>;
}

const PlayerContext = createContext<PlayerContext>({
  enqueueAndPlay: (_tracks, _startWithTrack?) => {},
  enqueueNext: (_tracks) => {},
  enqueueAfter: (_tracks) => {},
  populateUpNext: (_input) => {},
  userConfirmQueueReplace: () => new Promise((resolve) => resolve(true)),
});

export function usePlayer() {
  return useContext(PlayerContext);
}

export const PlayerProvider = ({ children }: PropsWithChildren) => {
  const {
    currentTrack,
    hasNextTrack,
    replaceQueue,
    addQueueNext,
    addQueueAfter,
  } = useQueue();
  const { isPlaying, setIsPlaying, scrubTo } = useAudioManager();
  const { promptConfirm } = useDialog();

  const enqueueAfter = useCallback(
    (tracks: Track[]) => {
      if (tracks.length === 0) return;

      addQueueAfter(tracks);
      if (!isPlaying && !currentTrack) setIsPlaying(true);
    },
    [setIsPlaying, isPlaying, currentTrack, addQueueAfter],
  );

  const populateUpNext = useCallback(
    async ({ artistId, albumId, random = false }: PopulateInput) => {
      const tracks = await queryTracks({ artistId, albumId, random });
      replaceQueue(tracks);
    },
    [replaceQueue],
  );

  const value = {
    enqueueAndPlay: useCallback(
      (tracks: Track[], startWithTrack?: Track) => {
        if (tracks.length === 0) return;

        replaceQueue(tracks, startWithTrack);
        if (!isPlaying) setIsPlaying(true);

        // If the user wants to play the current track from the beginning again
        // it technically doesn't change the state.. but we can seek to 0.
        if (isPlaying && startWithTrack === currentTrack) {
          scrubTo(0, true);
        }
      },
      [setIsPlaying, isPlaying, currentTrack, replaceQueue, scrubTo],
    ),
    enqueueNext: useCallback(
      (tracks: Track[]) => {
        if (tracks.length === 0) return;

        addQueueNext(tracks);
        if (!isPlaying && !currentTrack) setIsPlaying(true);
      },
      [setIsPlaying, isPlaying, currentTrack, addQueueNext],
    ),
    enqueueAfter,
    populateUpNext,
    userConfirmQueueReplace: useCallback(async () => {
      return (
        (await promptConfirm({
          when: () => currentTrack !== undefined || hasNextTrack,
          message: i18next.t("player.confirmQueue.replaceText", {
            defaultValue: "This will replace the current track and queue.",
          }),
          confirmMessage: i18next.t("player.confirmQueue.ok", {
            defaultValue: "OK",
          }),
          cancelMessage: i18next.t("player.confirmQueue.cancel", {
            defaultValue: "Cancel",
          }),
        })) === true
      );
    }, [currentTrack, hasNextTrack, promptConfirm]),
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};
