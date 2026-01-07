import { createContext, type ReactNode, useContext } from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import type { Track } from "../types";

export interface PlayerContext {
  // Queue management
  enqueueAndPlay(tracks: Track[], startWithTrack?: Track): void;
}

const PlayerContext = createContext<PlayerContext>({
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

  const value = {
    enqueueAndPlay(tracks: Track[], startWithTrack?: Track) {
      if (!Array.isArray(tracks)) tracks = [tracks];
      if (tracks.length === 0) return;

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
