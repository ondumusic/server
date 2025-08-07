import { createContext, useContext, useState } from "react";

const createAudio = () => {
  const audioEl = document.createElement("audio");
  audioEl.playsinline = true;
  document.body.appendChild(audioEl);
  return audioEl;
};

const playSong = (id) => {
  let audioEl = document.querySelector("audio");
  if (!audioEl) audioEl = createAudio();
  audioEl.src = `/stream/${id}`;
  audioEl.play();
};

const PlayerContext = createContext({
  isPlaying: false,
  currentSongId: null,
  playSong: () => {},
  setIsPlaying: () => {},
});

export function usePlayer() {
  return useContext(PlayerContext);
}

export const PlayerProvider = ({ children }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentSongId, setCurrentSongId] = useState(false);
  const value = {
    setIsPlaying,
    isPlaying,
    currentSongId,
    playSong: (id) => {
      setIsPlaying(true);
      setCurrentSongId(id);
      playSong(id);
    },
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};

