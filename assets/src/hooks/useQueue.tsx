import { createContext, type ReactNode, useContext, useState } from "react";
import type { Track } from "../types";

export interface QueueContext {
  queue: Track[];
  currentTrack?: Track;
  hasPrevTrack: boolean;
  hasNextTrack: boolean;
  prevTrack(): void;
  nextTrack(): void;
  getNextTrack(): Track | undefined;
  replaceQueue(tracks: Track[], startWithTrack?: Track): void;
}

const QueueContext = createContext<QueueContext>({
  queue: [],
  currentTrack: undefined,
  hasPrevTrack: false,
  hasNextTrack: false,
  prevTrack: () => {},
  nextTrack: () => {},
  getNextTrack: () => {},
  replaceQueue: (_tracks, _startWithTrack?) => {},
});

export function useQueue() {
  return useContext(QueueContext);
}

interface Props {
  children: ReactNode;
}

export const QueueProvider = ({ children }: Props) => {
  const [queue, setQueue] = useState<Track[]>([]);
  const [queueIndex, setQueueIndex] = useState(-1);
  const currentTrack = queue[queueIndex] ?? undefined;
  const hasNextTrack = queueIndex < queue.length - 1;
  const hasPrevTrack = queueIndex > 0;

  const value = {
    queue,
    currentTrack,
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
    replaceQueue(tracks: Track[], startWithTrack?: Track) {
      if (!Array.isArray(tracks)) tracks = [tracks];
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
