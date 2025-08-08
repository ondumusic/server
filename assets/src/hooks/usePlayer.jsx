import { createContext, useContext, useEffect, useRef, useState } from "react";
import { useQueue } from "../hooks/useQueue";

const PlayerContext = createContext({
  audioRef: null,
  isPlaying: false,
  currentSong: null,
  currentTime: 0,
  duration: 0,
  enqueueAndPlay: () => {},
  setCurrentTime: () => {},
});

export function usePlayer() {
  return useContext(PlayerContext);
}

export const PlayerProvider = ({ children }) => {
  const {
    queue,
    currentSong,
    replaceQueue,
    prevSong,
    nextSong,
    hasPrevSong,
    hasNextSong,
  } = useQueue();

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioRef = useRef(null);

  // This effect controls the actual playback, for example to switch between
  // playing and paused states. If there is no (more) song and it is set to
  // isPlaying it will set the player into a paused state.
  useEffect(() => {
    if (!audioRef || !audioRef.current) return;

    if (isPlaying && !currentSong) {
      setIsPlaying(false);
    } else if (isPlaying) {
      audioRef.current.play();
    } else {
      audioRef.current.pause();
    }
  }, [isPlaying, currentSong]);

  // When the currentSong changes we assume we are starting from 0 again so
  // reset to 0 and the audio event handlers will update it once metadata is
  // loaded and it starts playing.
  useEffect(() => {
    if (!currentSong) return;
    setDuration(0);
    setCurrentTime(0);
  }, [currentSong]);

  // Calculate the current playback percentage
  let progressPercentage = (currentTime / duration) * 100;
  if (Number.isNaN(progressPercentage)) progressPercentage = 0;

  const value = {
    audioRef,

    // Current queue and song information
    queue,
    hasPrevSong,
    hasNextSong,
    isPlaying,
    currentSong,
    currentTime,
    duration,
    progressPercentage,

    // State Management
    setCurrentTime,
    setDuration,
    setIsPlaying,

    // Queue Management
    prevSong,
    nextSong,
    enqueueAndPlay(songs, startIndex = 0) {
      if (!Array.isArray(songs)) songs = [songs];
      if (songs.length === 0) return;
      replaceQueue(songs, startIndex);
      if (!isPlaying) setIsPlaying(true);
    },
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};
