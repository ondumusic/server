import {
  type ChangeEvent,
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { useQueue } from "../hooks/useQueue";

export interface AudioManagerContext {
  isPlaying: boolean;
  duration: number;
  currentTime: number;
  progressPercentage: number;

  // State management
  setCurrentTime(currentTime: number): void;
  setDuration(duration: number): void;
  setIsPlaying(isPlaying: boolean): void;

  // Scrubbing functionality
  scrubTo(updatedTime: number): void;
  scrubAndPlay(updatedTime: number): void;
}

const AudioManagerContext = createContext<AudioManagerContext>({
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  progressPercentage: 0,
  setCurrentTime: (_currentTime) => {},
  setDuration: (_duration) => {},
  setIsPlaying: (_isPlaying) => {},
  scrubTo: (_updatedTime) => {},
  scrubAndPlay: (_updatedTime) => {},
});

export function useAudioManager() {
  return useContext(AudioManagerContext);
}

interface Props {
  children: ReactNode;
}

export const AudioManagerProvider = ({ children }: Props) => {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const { currentTrack, nextTrack } = useQueue();

  // Calculate the current playback percentage
  let progressPercentage = (currentTime / duration) * 100;
  if (Number.isNaN(progressPercentage)) progressPercentage = 0;

  // Pause/resume functionality
  useEffect(() => {
    if (!audioRef.current) return;

    if (!isPlaying || !currentTrack) {
      audioRef.current.pause();
    } else if (isPlaying) {
      audioRef.current.play();
    }
  }, [isPlaying, currentTrack]);

  // Reset when track changes
  useEffect(() => {
    if (!currentTrack) {
      setIsPlaying(false);

      // Make sure to also clear the <audio> tag to avoid the browser
      // being able to interact with the last played track.
      if (audioRef.current) {
        audioRef.current.src = "";
      }
    }

    setCurrentTime(0);
    setDuration(0);
  }, [currentTrack]);

  // Scrubbing functionality
  const scrubTo = (updatedTime: number) => {
    if (!audioRef.current) return;

    // Keep the updatedTime within bounds
    updatedTime = Math.max(0, Math.min(duration, updatedTime));

    // Set the currentTime
    setCurrentTime(updatedTime);
    audioRef.current.currentTime = updatedTime;
  };

  // Audio Event Listeners
  const onLoadedMetadata = (event: ChangeEvent<HTMLAudioElement>) => {
    setDuration(event.target.duration);
  };

  const onTimeUpdate = (event: ChangeEvent<HTMLAudioElement>) => {
    setCurrentTime(event.target.currentTime);
  };

  const onEnded = (_event: ChangeEvent<HTMLAudioElement>) => {
    nextTrack();
  };

  const value = {
    isPlaying,
    duration,
    currentTime,
    progressPercentage,
    setCurrentTime,
    setDuration,
    setIsPlaying,
    scrubTo,
    scrubAndPlay(updatedTime: number) {
      setIsPlaying(true);
      scrubTo(updatedTime);
    },
  };

  return (
    <AudioManagerContext.Provider value={value}>
      <audio
        ref={audioRef}
        src={currentTrack?.streamUrl}
        preload="auto"
        onLoadedMetadata={onLoadedMetadata}
        onTimeUpdate={onTimeUpdate}
        onEnded={onEnded}
      />
      {children}
    </AudioManagerContext.Provider>
  );
};
