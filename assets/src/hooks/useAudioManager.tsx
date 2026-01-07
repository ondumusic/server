import {
  type ChangeEvent,
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { useAuth } from "../hooks/useAuth";
import { usePlayTokenQuery } from "../hooks/usePlayTokenQuery";
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
  const endedTimer = useRef<ReturnType<typeof setTimeout>>(null);
  const { isLoggedIn } = useAuth();
  const [isPlaying, realSetIsPlaying] = useState(false);
  const [hasPreloadedNext, setHasPreloadedNext] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [source, setSource] = useState<string | undefined>(undefined);
  const { currentTrack, nextTrack, hasNextTrack, getNextTrack } = useQueue();
  const { playToken } = usePlayTokenQuery({ enabled: isLoggedIn });

  // Control play/pause directly but also update state.
  const setIsPlaying = (isPlaying: boolean) => {
    if (endedTimer.current) clearTimeout(endedTimer.current);
    if (!audioRef.current) return;
    realSetIsPlaying(isPlaying);

    if (!isPlaying) {
      audioRef.current.pause();
    } else if (audioRef.current.src) {
      audioRef.current.play();
    }
  };

  // Calculate the current playback percentage
  let progressPercentage = (currentTime / duration) * 100;
  if (Number.isNaN(progressPercentage)) progressPercentage = 0;

  // biome-ignore lint/correctness/useExhaustiveDependencies(getNextTrack): suppress dependency getNextTrack
  useEffect(() => {
    if (hasPreloadedNext) return;
    if (!hasNextTrack) return;
    if (progressPercentage < 70) return;

    setHasPreloadedNext(true);
    const nextTrack = getNextTrack();
    if (!nextTrack) return;

    // We don't really care about the response for this, it returns a static
    // ok response because the transcoder starts as a background process.
    // api.post(`/transcode/${nextTrack.id}`, null);
  }, [hasNextTrack, hasPreloadedNext, progressPercentage]);

  // Reset when track changes
  // We don't want to track when playToken changes because that would interrupt playback
  // biome-ignore lint/correctness/useExhaustiveDependencies(playToken): suppress dependency playToken
  // biome-ignore lint/correctness/useExhaustiveDependencies(setIsPlaying): suppress dependency setIsPlaying
  useEffect(() => {
    if (endedTimer.current) clearTimeout(endedTimer.current);
    if (!currentTrack) {
      setSource(undefined);
      setIsPlaying(false);

      // Make sure to also clear the <audio> tag to avoid the browser
      // being able to interact with the last played track.
      if (audioRef.current) {
        audioRef.current.src = "";
      }
    } else {
      setSource(`${currentTrack.streamUrl}?transcode=1&token=${playToken}`);
    }

    setHasPreloadedNext(false);
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
    let duration = event.target.duration;
    if (!Number.isFinite(duration)) duration = currentTrack?.duration ?? 0;
    setDuration(duration);
  };

  const onTimeUpdate = (event: ChangeEvent<HTMLAudioElement>) => {
    if (endedTimer.current) clearTimeout(endedTimer.current);

    if (
      currentTrack &&
      currentTrack.duration - event.target.currentTime < 0.2
    ) {
      endedTimer.current = setTimeout(nextTrack, 200);
    }

    setCurrentTime(event.target.currentTime);
  };

  const onEnded = (_event: ChangeEvent<HTMLAudioElement>) => {
    if (endedTimer.current) clearTimeout(endedTimer.current);
    nextTrack();
  };

  const onPause = (_event: ChangeEvent<HTMLAudioElement>) => {
    if (endedTimer.current) clearTimeout(endedTimer.current);
    if (!audioRef.current) return;
    if (audioRef.current.ended) return;
    setIsPlaying(false);
  };

  const onCanPlay = (_event: ChangeEvent<HTMLAudioElement>) => {
    if (!audioRef.current) return;
    audioRef.current.play();
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
      {source && (
        <audio
          ref={audioRef}
          src={source}
          preload="auto"
          controls={true}
          className="hidden absolute top-0 left-0 z-[1000]"
          onLoadedMetadata={onLoadedMetadata}
          onTimeUpdate={onTimeUpdate}
          onCanPlay={onCanPlay}
          onPause={onPause}
          onPlay={() => setIsPlaying(true)}
          onEnded={onEnded}
        />
      )}
      {children}
    </AudioManagerContext.Provider>
  );
};
