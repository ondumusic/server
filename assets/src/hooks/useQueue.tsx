import { createContext, type ReactNode, useContext, useState } from "react";
import type { Song } from "../types";

export interface QueueContext {
  queue: Song[];
  currentSong?: Song;
  hasPrevSong: boolean;
  hasNextSong: boolean;
  prevSong(): void;
  nextSong(): void;
  replaceQueue(songs: Song[], startWithSong?: Song): void;
}

const QueueContext = createContext<QueueContext>({
  queue: [],
  currentSong: undefined,
  hasPrevSong: false,
  hasNextSong: false,
  prevSong: () => {},
  nextSong: () => {},
  replaceQueue: (_songs, _startWithSong?) => {},
});

export function useQueue() {
  return useContext(QueueContext);
}

interface Props {
  children: ReactNode;
}

export const QueueProvider = ({ children }: Props) => {
  const [queue, setQueue] = useState<Song[]>([]);
  const [queueIndex, setQueueIndex] = useState(0);
  const currentSong = queue[queueIndex] ?? undefined;
  const hasNextSong = queueIndex < queue.length - 1;
  const hasPrevSong = queueIndex > 0;

  const value = {
    queue,
    currentSong,
    hasPrevSong,
    hasNextSong,
    prevSong() {
      const prevSongIndex = Math.max(0, queueIndex - 1);
      setQueueIndex(prevSongIndex);
    },
    nextSong() {
      const nextSongIndex = Math.min(queue.length, queueIndex + 1);
      setQueueIndex(nextSongIndex);
    },
    replaceQueue(songs: Song[], startWithSong?: Song) {
      if (!Array.isArray(songs)) songs = [songs];
      let startIndex = songs.findIndex(({ id }) => id === startWithSong?.id);
      startIndex = Math.max(Math.min(songs.length - 1, startIndex), 0);
      setQueue(songs);
      setQueueIndex(startIndex);
    },
  };

  return (
    <QueueContext.Provider value={value}>{children}</QueueContext.Provider>
  );
};
