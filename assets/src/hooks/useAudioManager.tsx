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
  const { currentTrack, currentTrackIndex, nextTrack } = useQueue();

  // Manage the AudioService (only execute on first render/mount)
  useEffect(() => {
    if (!isLoggedIn) return;
    audioService.current = new AudioService();

    return () => {
      if (!audioService.current) return;
      audioService.current.destroy();
    };
  }, [isLoggedIn]);

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

  // Reset when track changes
  // biome-ignore lint/correctness/useExhaustiveDependencies(setIsPlaying): suppress dependency setIsPlaying
  // biome-ignore lint/correctness/useExhaustiveDependencies(emitTimeUpdate): suppress dependency emitTimeUpdate
  useEffect(() => {
    if (!audioService.current) return;

    if (!currentTrack) {
      audioService.current.stop();
      setIsPlaying(false);
      setDuration(0);
      emitTimeUpdate({
        currentTime: 0,
        progressPercentage: 0,
      });
    } else {
      emitTimeUpdate({
        currentTime: 0,
        progressPercentage: 0,
      });

      audioService?.current.play({
        ...currentTrack,
        queueIndex: currentTrackIndex,
      });
    }
  }, [currentTrack, currentTrackIndex]);

  // Scrubbing functionality
  const scrubTo = (updatedTime: number, forcePlay: boolean = false) => {
    if (!audioService.current) return;

    // Keep the updatedTime within bounds
    updatedTime = Math.max(0, Math.min(duration, updatedTime));
    audioService.current.scrubTo(updatedTime, forcePlay);

    let progressPercentage = (updatedTime / duration) * 100;
    if (Number.isNaN(progressPercentage)) progressPercentage = 0;

    emitTimeUpdate({
      currentTime: updatedTime,
      progressPercentage,
    });
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
