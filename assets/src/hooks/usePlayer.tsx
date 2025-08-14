import { createContext, type ReactNode, useContext, useState } from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import type { Track } from "../types";

export interface PlayerContext {
  // State management
  isVisible: boolean;
  setIsVisible(isVisible: boolean): void;

  // Queue management
  enqueueAndPlay(tracks: Track[], startWithTrack?: Track): void;
}

const PlayerContext = createContext<PlayerContext>({
  isVisible: false,
  setIsVisible: (_isVisible) => {},
  enqueueAndPlay: (_tracks, _startWithTrack?) => {},
});

export function usePlayer() {
  return useContext(PlayerContext);
}

interface Props {
  children: ReactNode;
}

export const PlayerProvider = ({ children }: Props) => {
  const { currentTrack, replaceQueue } = useQueue();

  const { isPlaying, setIsPlaying, scrubAndPlay } = useAudioManager();

  const [isVisible, setIsVisible] = useState(false);

  const value = {
    isVisible,
    setIsVisible,
    enqueueAndPlay(tracks: Track[], startWithTrack?: Track) {
      if (!Array.isArray(tracks)) tracks = [tracks];
      if (tracks.length === 0) return;
      setIsVisible(true);

      replaceQueue(tracks, startWithTrack);
      if (!isPlaying) setIsPlaying(true);

      // If the user wants to play the current track from the beginning again
      // it technically doesn't change the state.. but we can seek to 0.
      if (isPlaying && startWithTrack === currentTrack) {
        scrubAndPlay(0);
      }
    },
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};
