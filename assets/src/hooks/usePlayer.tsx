import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
} from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { useDialog } from "../hooks/useDialog";
import { type QueueItem, useQueue } from "../hooks/useQueue";
import i18next from "../i18next";
import { queryPlaylistItems, queryTracks } from "../library";
import type { Track, UUID } from "../types";

export interface PopulateInput {
  artistId?: UUID;
  albumId?: UUID;
  albumIds?: UUID[];
  playlistId?: UUID;
  random?: boolean;
}

export interface PlayerContext {
  // Queue management
  enqueueAndPlay(items: QueueItem[], startWithItem?: QueueItem): void;
  enqueueNext(items: QueueItem[]): void;
  enqueueAfter(items: QueueItem[]): void;
  populateUpNext(input: PopulateInput): void;
  userConfirmQueueReplace(): Promise<boolean>;
}

const PlayerContext = createContext<PlayerContext>({
  enqueueAndPlay: (_items, _startWithItem?) => {},
  enqueueNext: (_items) => {},
  enqueueAfter: (_items) => {},
  populateUpNext: (_input) => {},
  userConfirmQueueReplace: () => new Promise((resolve) => resolve(true)),
});

export function usePlayer() {
  return useContext(PlayerContext);
}

export const PlayerProvider = ({ children }: PropsWithChildren) => {
  const {
    currentTrack,
    currentItem,
    hasNextTrack,
    replaceQueue,
    addQueueNext,
    addQueueAfter,
  } = useQueue();
  const { isPlaying, setIsPlaying, scrubTo } = useAudioManager();
  const { promptConfirm } = useDialog();

  const enqueueAfter = useCallback(
    (items: QueueItem[]) => {
      if (items.length === 0) return;

      addQueueAfter(items);
      if (!isPlaying && !currentTrack) setIsPlaying(true);
    },
    [setIsPlaying, isPlaying, currentTrack, addQueueAfter],
  );

  const populateUpNext = useCallback(
    async ({
      artistId,
      albumId,
      albumIds,
      playlistId,
      random = false,
    }: PopulateInput) => {
      if (playlistId) {
        const items = await queryPlaylistItems(playlistId, random);
        replaceQueue(
          items.map((item) => ({
            track: item.track as Track,
            meta: {
              playlistItemId: item.id,
            },
          })),
        );
      } else {
        const tracks = await queryTracks({
          artistId,
          albumId,
          albumIds,
          random,
        });
        replaceQueue(tracks.map((track) => ({ track })));
      }
    },
    [replaceQueue],
  );

  const value = {
    enqueueAndPlay: useCallback(
      (items: QueueItem[], startWithItem?: QueueItem) => {
        if (items.length === 0) return;

        replaceQueue(items, startWithItem);
        if (!isPlaying) setIsPlaying(true);

        // If the user wants to play the current track from the beginning again
        // it technically doesn't change the state.. but we can seek to 0.
        if (isPlaying && startWithItem === currentItem) {
          scrubTo(0, true);
        }
      },
      [setIsPlaying, isPlaying, currentItem, replaceQueue, scrubTo],
    ),
    enqueueNext: useCallback(
      (items: QueueItem[]) => {
        if (items.length === 0) return;

        addQueueNext(items);
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
