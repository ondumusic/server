import { createContext, useContext, useState } from "react";

const QueueContext = createContext({
  queue: [],
  currentSong: null,
  hasPrevSong: false,
  hasNextSong: false,
  prevSong: () => {},
  nextSong: () => {},
  replaceQueue: () => {},
});

export function useQueue() {
  return useContext(QueueContext);
}

export const QueueProvider = ({ children }) => {
  const [queue, setQueue] = useState([]);
  const [queueIndex, setQueueIndex] = useState(0);
  const currentSong = queue[queueIndex] ?? null;

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
    replaceQueue(songs, startIndex = 0) {
      if (!Array.isArray(songs)) songs = [songs];

      if (typeof startIndex === "object") {
        startIndex = songs.findIndex(({ id }) => id === startIndex.id);
      }

      startIndex = Math.max(Math.min(songs.length - 1, startIndex), 0);
      setQueue(songs);
      setQueueIndex(startIndex);
    },
  };

  return (
    <QueueContext.Provider value={value}>{children}</QueueContext.Provider>
  );
};
