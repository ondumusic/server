import { createContext, useContext, useEffect, useRef, useState } from "react";

const PlayerContext = createContext({
  audioRef: null,
  isPlaying: false,
  currentSong: null,
  currentTime: 0,
  duration: 0,
  percentage: 0,
  playSong: () => {},
  setIsPlaying: () => {},
  setCurrentSong: () => {},
  setCurrentTime: () => {},
  setPercentage: () => {},
});

export function usePlayer() {
  return useContext(PlayerContext);
}

export const PlayerProvider = ({ children }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentSong, setCurrentSong] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [percentage, setPercentage] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioRef = useRef(null);

  // biome-ignore lint/correctness/useExhaustiveDependencies(currentSong): suppress dependency currentSong
  useEffect(() => {
    if (!audioRef || !audioRef.current) return;

    if (isPlaying) {
      audioRef.current.currentTime = 0;
      audioRef.current.play();
    } else {
      audioRef.current.pause();
    }
  }, [isPlaying, currentSong]);

  const value = {
    audioRef,
    setIsPlaying,
    isPlaying,
    currentSong,
    currentTime,
    setCurrentTime,
    setDuration,
    duration,
    setPercentage,
    percentage,
    playSong: (song) => {
      setIsPlaying(true);
      setDuration(song.duration);
      setPercentage(0);
      setCurrentTime(0);
      setCurrentSong(song);
    },
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};
