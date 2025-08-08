import { createContext, useContext, useEffect, useRef, useState } from "react";

const PlayerContext = createContext({
  audioRef: null,
  isPlaying: false,
  currentSong: null,
  playSong: () => {},
  setIsPlaying: () => {},
});

export function usePlayer() {
  return useContext(PlayerContext);
}

export const PlayerProvider = ({ children }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentSong, setCurrentSong] = useState(false);
  const audioRef = useRef(null);

  // biome-ignore lint/correctness/useExhaustiveDependencies(currentSong): suppress dependency currentSong
  useEffect(() => {
    if (!audioRef || !audioRef.current) return;

    if (isPlaying) {
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
    playSong: (song) => {
      setIsPlaying(true);
      setCurrentSong(song);
    },
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};
