import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { useAuth } from "../hooks/useAuth";
import { type Observer, useObserver } from "../hooks/useObserver";
import { usePlayTokenQuery } from "../hooks/usePlayTokenQuery";
import { useQueue } from "../hooks/useQueue";
import { AudioService } from "../services/audio";

interface TimeUpdateEvent {
  currentTime: number;
  progressPercentage: number;
}

export interface AudioManagerContext {
  isPlaying: boolean;
  duration: number;

  // State management
  setIsPlaying(isPlaying: boolean): void;

  // Observers
  addTimeObserver(callback: Observer<TimeUpdateEvent>): void;

  // Scrubbing functionality
  scrubTo(updatedTime: number, forcePlay?: boolean): void;
}

const AudioManagerContext = createContext<AudioManagerContext>({
  isPlaying: false,
  duration: 0,
  setIsPlaying: (_isPlaying) => {},
  addTimeObserver: (_callback) => {},
  scrubTo: (_updatedTime, _forcePlay) => {},
});

export function useAudioManager() {
  return useContext(AudioManagerContext);
}

export const AudioManagerProvider = ({ children }: PropsWithChildren) => {
  const audioService = useRef<AudioService>(null);
  const { isLoggedIn } = useAuth();
  const [isPlaying, realSetIsPlaying] = useState(false);
  const [emitTimeUpdate, addTimeObserver] = useObserver<TimeUpdateEvent>();
  const [duration, setDuration] = useState(0);
  const { currentTrack, nextTrack, hasNextTrack, getNextTrack } = useQueue();
  const { playToken } = usePlayTokenQuery({ enabled: isLoggedIn });

  // Manage the AudioService (only execute on first render/mount)
  // biome-ignore lint/correctness/useExhaustiveDependencies(playToken): suppress dependency playToken
  useEffect(() => {
    audioService.current = new AudioService();
    if (playToken) audioService.current.setPlayToken(playToken);

    return () => {
      if (!audioService.current) return;
      audioService.current.destroy();
    };
  }, []);

  // Make sure the PlayToken is up to date
  useEffect(() => {
    if (!audioService.current) return;
    if (!playToken) return;
    audioService.current.setPlayToken(playToken);
  }, [playToken]);

  // Subscribe to Audio Service Events
  useEffect(() => {
    if (!audioService.current) return;

    const unsubscribe = audioService.current.on("timeupdate", (e) => {
      realSetIsPlaying(e.isPlaying);
      setDuration(e.duration);
      emitTimeUpdate({
        currentTime: e.currentTime,
        progressPercentage: e.progressPercentage,
      });
    });

    const unsubscribe2 = audioService.current.on("ended", () => {
      nextTrack();
    });

    return () => {
      unsubscribe();
      unsubscribe2();
    };
  }, [nextTrack, emitTimeUpdate]);

  // Control play/pause directly (but also update state).
  const setIsPlaying = (playing: boolean) => {
    if (!audioService.current) return;

    if (!playing) {
      audioService.current.pause();
      realSetIsPlaying(false);
    } else {
      audioService.current.resume();
      realSetIsPlaying(true);
    }
  };

  // Preload next track to improve playback experience
  useEffect(() => {
    if (!hasNextTrack) return;

    return addTimeObserver(({ progressPercentage }) => {
      if (progressPercentage < 70) return;

      const nextTrack = getNextTrack();
      if (!nextTrack) return;

      if (audioService.current) {
        audioService.current.preload(nextTrack);
      }
    });
  }, [hasNextTrack, getNextTrack, addTimeObserver]);

  // Reset when track changes
  // We don't want to track when playToken changes because that would interrupt playback
  // biome-ignore lint/correctness/useExhaustiveDependencies(setIsPlaying): suppress dependency setIsPlaying
  // biome-ignore lint/correctness/useExhaustiveDependencies(emitTimeUpdate): suppress dependency emitTimeUpdate
  useEffect(() => {
    if (!audioService.current) return;

    setDuration(0);
    emitTimeUpdate({
      currentTime: 0,
      progressPercentage: 0,
    });

    if (!currentTrack) {
      audioService.current.stop();
      setIsPlaying(false);
    } else {
      audioService?.current.play(currentTrack);
    }
  }, [currentTrack]);

  // Scrubbing functionality
  const scrubTo = (updatedTime: number, forcePlay: boolean = false) => {
    if (!audioService.current) return;

    // Keep the updatedTime within bounds
    updatedTime = Math.max(0, Math.min(duration, updatedTime));
    audioService.current.scrubTo(updatedTime, forcePlay);
  };

  const value = {
    isPlaying,
    duration,
    addTimeObserver,
    setIsPlaying,
    scrubTo,
  };

  return (
    <AudioManagerContext.Provider value={value}>
      {children}
    </AudioManagerContext.Provider>
  );
};
