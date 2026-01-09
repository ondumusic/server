import {
  createContext,
  type PropsWithChildren,
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
  addQueueNext(tracks: Track[]): void;
  replaceQueue(tracks: Track[], startWithTrack?: Track): void;
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
  addQueueNext: (_tracks) => {},
  replaceQueue: (_tracks, _startWithTrack?) => {},
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
    getNextTrack() {
      const nextTrackIndex = queueIndex + 1;
      if (nextTrackIndex >= queue.length) {
        return;
      }

      return queue[nextTrackIndex];
    },
    prevTrack() {
      const prevTrackIndex = Math.max(-1, queueIndex - 1);
      setQueueIndex(prevTrackIndex);
    },
    nextTrack() {
      let nextTrackIndex = queueIndex + 1;
      if (nextTrackIndex >= queue.length) {
        nextTrackIndex = -1;
      }

      setQueueIndex(nextTrackIndex);
    },
    addQueueNext(tracks: Track[]) {
      const updatedQueue = [...queue];
      updatedQueue.splice(queueIndex + 1, 0, ...tracks);
      setQueue(updatedQueue);

      // Set queue index to 0 if the queue was empty previously,
      // indicating that the current track is the 1st track of the new queue.
      if (queue.length === 0) {
        setQueueIndex(0);
      }
    },
    replaceQueue(tracks: Track[], startWithTrack?: Track) {
      let startIndex = tracks.findIndex(({ id }) => id === startWithTrack?.id);
      startIndex = Math.max(Math.min(tracks.length - 1, startIndex), 0);
      setQueue(tracks);
      setQueueIndex(startIndex);
    },
  };

  return (
    <QueueContext.Provider value={value}>{children}</QueueContext.Provider>
  );
};
