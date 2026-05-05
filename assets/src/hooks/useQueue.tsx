import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useState,
} from "react";
import type { Track } from "../types";

export type QueueItem = {
  track: Track;
  meta?: {
    [key: string]: string;
  };
};

export interface QueueContext {
  queue: QueueItem[];
  currentItem?: QueueItem;
  currentTrack?: Track;
  currentTrackIndex: number;
  hasPrevTrack: boolean;
  hasNextTrack: boolean;
  prevTrack(): void;
  nextTrack(): void;
  getNextTrack(): Track | undefined;
  skipToTrackIndex(trackIndex: number): void;
  addQueueNext(items: QueueItem[]): void;
  addQueueAfter(items: QueueItem[]): void;
  addQueueAtIndex(items: QueueItem[], index: number): void;
  rearrangeQueue(indexes: Set<number>, index: number): void;
  replaceQueue(items: QueueItem[], startWithItem?: QueueItem): void;
  removeFromQueue(trackIndexes: number[]): void;
  clearNextTracks(): void;
  clearQueue(): void;
}

const QueueContext = createContext<QueueContext>({
  queue: [],
  currentItem: undefined,
  currentTrack: undefined,
  currentTrackIndex: -1,
  hasPrevTrack: false,
  hasNextTrack: false,
  prevTrack: () => {},
  nextTrack: () => {},
  getNextTrack: () => undefined,
  skipToTrackIndex: (_trackIndex) => {},
  addQueueNext: (_items) => {},
  addQueueAfter: (_items) => {},
  addQueueAtIndex: (_items, _index) => {},
  replaceQueue: (_items, _startWithItem?) => {},
  rearrangeQueue: (_indexes, _index) => {},
  removeFromQueue: (_trackIndex) => {},
  clearNextTracks: () => {},
  clearQueue: () => {},
});

export function useQueue() {
  return useContext(QueueContext);
}

export const QueueProvider = ({ children }: PropsWithChildren) => {
  const [queue, setQueue] = useState<QueueItem[]>([]);
  const [queueIndex, setQueueIndex] = useState(-1);
  const currentItem = queue[queueIndex] ?? undefined;
  const currentTrack = queue[queueIndex]?.track ?? undefined;
  const hasNextTrack = queueIndex < queue.length - 1;
  const hasPrevTrack = queueIndex > 0;

  const value = {
    queue,
    currentItem,
    currentTrack,
    currentTrackIndex: queueIndex,
    hasPrevTrack,
    hasNextTrack,
    getNextTrack: useCallback(() => {
      const nextTrackIndex = queueIndex + 1;
      if (nextTrackIndex >= queue.length) {
        return;
      }

      return queue[nextTrackIndex].track;
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
      (items: QueueItem[]) => {
        const updatedQueue = [...queue];
        updatedQueue.splice(queueIndex + 1, 0, ...items);
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
      (items: QueueItem[]) => {
        setQueue((currentQueue) => currentQueue.concat(items));

        // Set queue index to 0 if the queue was empty previously,
        // indicating that the current track is the 1st track of the new queue.
        if (queue.length === 0) {
          setQueueIndex(0);
        }
      },
      [queue],
    ),
    addQueueAtIndex: useCallback(
      (items: QueueItem[], index: number) => {
        const updatedQueue = [...queue];
        updatedQueue.splice(index, 0, ...items);
        setQueue(updatedQueue);

        // Set queue index to 0 if the queue was empty previously,
        // indicating that the current track is the 1st track of the new queue.
        if (queue.length === 0) {
          setQueueIndex(0);
        }
      },
      [queue],
    ),
    replaceQueue: useCallback(
      (items: QueueItem[], startWithItem?: QueueItem) => {
        let startIndex = startWithItem ? items.indexOf(startWithItem) : 0;
        startIndex = Math.max(Math.min(items.length - 1, startIndex), 0);
        setQueue(items);
        setQueueIndex(startIndex);
      },
      [],
    ),
    rearrangeQueue: useCallback(
      (indexes: Set<number>, index: number) => {
        const selected: QueueItem[] = [],
          remaining: QueueItem[] = [];

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
      setQueue((_oldQueue) => []);
      setQueueIndex((_oldIndex) => -1);
    }, []),
  };

  return (
    <QueueContext.Provider value={value}>{children}</QueueContext.Provider>
  );
};
