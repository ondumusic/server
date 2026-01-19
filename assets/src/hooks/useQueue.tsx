import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useState,
} from "react";
import type { Track } from "../types";

export interface QueueContext {
  queue: Track[];
  currentTrack?: Track;
  currentTrackIndex: number;
  hasPrevTrack: boolean;
  hasNextTrack: boolean;
  prevTrack(): void;
  nextTrack(): void;
  getNextTrack(): Track | undefined;
  skipToTrackIndex(trackIndex: number): void;
  addQueueNext(tracks: Track[]): void;
  addQueueAfter(tracks: Track[]): void;
  addQueueAtIndex(tracks: Track[], index: number): void;
  rearrangeQueue(indexes: Set<number>, index: number): void;
  replaceQueue(tracks: Track[], startWithTrack?: Track): void;
  removeFromQueue(trackIndexes: number[]): void;
  clearNextTracks(): void;
  clearQueue(): void;
}

const QueueContext = createContext<QueueContext>({
  queue: [],
  currentTrack: undefined,
  currentTrackIndex: -1,
  hasPrevTrack: false,
  hasNextTrack: false,
  prevTrack: () => {},
  nextTrack: () => {},
  getNextTrack: () => undefined,
  skipToTrackIndex: (_trackIndex) => {},
  addQueueNext: (_tracks) => {},
  addQueueAfter: (_tracks) => {},
  addQueueAtIndex: (_tracks, _index) => {},
  replaceQueue: (_tracks, _startWithTrack?) => {},
  rearrangeQueue: (_indexes, _index) => {},
  removeFromQueue: (_trackIndex) => {},
  clearNextTracks: () => {},
  clearQueue: () => {},
});

export function useQueue() {
  return useContext(QueueContext);
}

export const QueueProvider = ({ children }: PropsWithChildren) => {
  const [queue, setQueue] = useState<Track[]>([]);
  const [queueIndex, setQueueIndex] = useState(-1);
  const currentTrack = queue[queueIndex] ?? undefined;
  const hasNextTrack = queueIndex < queue.length - 1;
  const hasPrevTrack = queueIndex > 0;

  const value = {
    queue,
    currentTrack,
    currentTrackIndex: queueIndex,
    hasPrevTrack,
    hasNextTrack,
    getNextTrack: useCallback(() => {
      const nextTrackIndex = queueIndex + 1;
      if (nextTrackIndex >= queue.length) {
        return;
      }

      return queue[nextTrackIndex];
    }, [queueIndex, queue]),
    prevTrack: useCallback(() => {
      const prevTrackIndex = Math.max(-1, queueIndex - 1);
      setQueueIndex(prevTrackIndex);
    }, [queueIndex]),
    nextTrack: useCallback(() => {
      let nextTrackIndex = queueIndex + 1;
      if (nextTrackIndex >= queue.length) {
        nextTrackIndex = -1;
      }

      setQueueIndex(nextTrackIndex);
    }, [queue, queueIndex]),
    skipToTrackIndex: useCallback((trackIndex: number) => {
      setQueueIndex(trackIndex);
    }, []),
    addQueueNext: useCallback(
      (tracks: Track[]) => {
        const updatedQueue = [...queue];
        updatedQueue.splice(queueIndex + 1, 0, ...tracks);
        setQueue(updatedQueue);

        // Set queue index to 0 if the queue was empty previously,
        // indicating that the current track is the 1st track of the new queue.
        if (queue.length === 0) {
          setQueueIndex(0);
        }
      },
      [queue, queueIndex],
    ),
    addQueueAfter: useCallback(
      (tracks: Track[]) => {
        const updatedQueue = queue.concat(tracks);
        setQueue(updatedQueue);

        // Set queue index to 0 if the queue was empty previously,
        // indicating that the current track is the 1st track of the new queue.
        if (queue.length === 0) {
          setQueueIndex(0);
        }
      },
      [queue],
    ),
    addQueueAtIndex: useCallback(
      (tracks: Track[], index: number) => {
        const updatedQueue = [...queue];
        updatedQueue.splice(index, 0, ...tracks);
        setQueue(updatedQueue);

        // Set queue index to 0 if the queue was empty previously,
        // indicating that the current track is the 1st track of the new queue.
        if (queue.length === 0) {
          setQueueIndex(0);
        }
      },
      [queue],
    ),
    replaceQueue: useCallback((tracks: Track[], startWithTrack?: Track) => {
      let startIndex = tracks.findIndex(({ id }) => id === startWithTrack?.id);
      startIndex = Math.max(Math.min(tracks.length - 1, startIndex), 0);
      setQueue(tracks);
      setQueueIndex(startIndex);
    }, []),
    rearrangeQueue: useCallback(
      (indexes: Set<number>, index: number) => {
        const selected: Track[] = [],
          remaining: Track[] = [];

        queue.forEach((item, i) => {
          if (indexes.has(i)) {
            selected.push(item);
          } else {
            remaining.push(item);
          }
        });

        // Adjust target index: count how many selected items were before the target
        const itemsBeforeIndex = Array.from(indexes).filter(
          (i) => i < index,
        ).length;
        const adjustedIndex = index - itemsBeforeIndex;

        // Insert selected items at adjusted target index
        remaining.splice(adjustedIndex, 0, ...selected);
        setQueue(remaining);
      },
      [queue],
    ),
    removeFromQueue: useCallback(
      (trackIndexes: number[]) => {
        const removeIndexes = new Set(trackIndexes);
        setQueue(
          queue.filter((_track, trackIndex) => !removeIndexes.has(trackIndex)),
        );
      },
      [queue],
    ),
    clearNextTracks: useCallback(() => {
      setQueue(queue.filter((_track, trackIndex) => trackIndex <= queueIndex));
    }, [queue, queueIndex]),
    clearQueue: useCallback(() => {
      setQueue([]);
      setQueueIndex(-1);
    }, []),
  };

  return (
    <QueueContext.Provider value={value}>{children}</QueueContext.Provider>
  );
};
