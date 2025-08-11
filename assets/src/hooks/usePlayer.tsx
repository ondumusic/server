import {
  createContext,
  type ReactNode,
  type RefObject,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { useQueue } from "../hooks/useQueue";
import type { Album, Track } from "../types";
import { findCachedItem } from "../utils/findCachedItem";

export interface PlayerContextT {
  audioRef: RefObject<HTMLAudioElement | null>;
  isVisible: boolean;

  // Current queue and track information
  queue: Track[];
  hasPrevTrack: boolean;
  hasNextTrack: boolean;
  isPlaying: boolean;
  currentTrack?: Track;
  currentTime: number;
  duration: number;
  progressPercentage: number;

  // State Management
  setCurrentTime(currentTime: number): void;
  setDuration(duration: number): void;
  setIsPlaying(isPlaying: boolean): void;
  setIsVisible(isVisible: boolean): void;

  // Queue Management
  prevTrack(): void;
  nextTrack(): void;
  enqueueAndPlay(tracks: Track[], startWithTrack?: Track): void;
}

const PlayerContext = createContext<PlayerContextT>({
  audioRef: { current: null },
  isVisible: false,
  queue: [],
  hasPrevTrack: false,
  hasNextTrack: false,
  isPlaying: false,
  currentTrack: undefined,
  currentTime: 0,
  duration: 0,
  progressPercentage: 0,
  setCurrentTime: (_currentTime) => {},
  setDuration: (_duration) => {},
  setIsPlaying: (_isPlaying) => {},
  setIsVisible: (_isVisible) => {},
  prevTrack: () => {},
  nextTrack: () => {},
  enqueueAndPlay: (_tracks, _startWithTrack?) => {},
});

export function usePlayer() {
  return useContext(PlayerContext);
}

interface Props {
  children: ReactNode;
}

export const PlayerProvider = ({ children }: Props) => {
  const {
    queue,
    currentTrack,
    replaceQueue,
    prevTrack,
    nextTrack,
    hasPrevTrack,
    hasNextTrack,
  } = useQueue();

  const [isVisible, setIsVisible] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioRef = useRef<HTMLAudioElement>(null);

  // This effect controls the actual playback, for example to switch between
  // playing and paused states. If there is no (more) track and it is set to
  // isPlaying it will set the player into a paused state.
  useEffect(() => {
    if (!audioRef.current) return;

    if (isPlaying && !currentTrack) {
      setIsPlaying(false);
    } else if (isPlaying) {
      audioRef.current.play();
    } else {
      audioRef.current.pause();
    }
  }, [isPlaying, currentTrack]);

  // When the currentTrack changes we assume we are starting from 0 again so
  // reset to 0 and the audio event handlers will update it once metadata is
  // loaded and it starts playing.
  useEffect(() => {
    if (!currentTrack) return;
    setDuration(0);
    setCurrentTime(0);
  }, [currentTrack]);

  const currentAlbum: Album | undefined = useMemo(() => {
    if (!currentTrack) return undefined;
    return findCachedItem<Album>(
      ["albumList", currentTrack?.artistId],
      currentTrack?.albumId,
    );
  }, [currentTrack]);

  // Experimenting with MediaSession
  useEffect(() => {
    if (!currentTrack) {
      navigator.mediaSession.metadata = null;
      navigator.mediaSession.setActionHandler("play", null);
      navigator.mediaSession.setActionHandler("pause", null);
      navigator.mediaSession.setActionHandler("stop", null);
      navigator.mediaSession.setActionHandler("previoustrack", null);
      navigator.mediaSession.setActionHandler("nexttrack", null);

      // TODO: Look into implementing these:
      // seekbackward
      // seekforward
      // seekto
    } else {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: currentTrack?.name,
        artist: currentTrack?.artist?.name,
        album: currentAlbum?.name,
        artwork: [],
      });

      navigator.mediaSession.setActionHandler("play", () => {
        setIsPlaying(true);
      });

      navigator.mediaSession.setActionHandler("pause", () => {
        setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("stop", () => {
        setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("previoustrack", () => {
        if (hasPrevTrack) prevTrack();
        else setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("nexttrack", () => {
        if (hasNextTrack) nextTrack();
        else setIsPlaying(false);
      });
    }
  }, [
    hasNextTrack,
    hasPrevTrack,
    nextTrack,
    prevTrack,
    currentTrack,
    currentAlbum,
  ]);

  // Calculate the current playback percentage
  let progressPercentage = (currentTime / duration) * 100;
  if (Number.isNaN(progressPercentage)) progressPercentage = 0;

  const value = {
    audioRef,
    isVisible,

    // Current queue and track information
    queue,
    hasPrevTrack,
    hasNextTrack,
    isPlaying,
    currentTrack,
    currentTime,
    duration,
    progressPercentage,

    // State Management
    setCurrentTime,
    setDuration,
    setIsPlaying,
    setIsVisible,

    // Queue Management
    prevTrack,
    nextTrack,
    enqueueAndPlay(tracks: Track[], startWithTrack?: Track) {
      if (!Array.isArray(tracks)) tracks = [tracks];
      if (tracks.length === 0) return;
      setIsVisible(true);

      replaceQueue(tracks, startWithTrack);
      if (!isPlaying) setIsPlaying(true);

      // If the user wants to play the current track from the beginning again
      // it technically doesn't change the state.. but we can seek to 0.
      if (isPlaying && startWithTrack === currentTrack) {
        if (!audioRef.current) return;
        audioRef.current.currentTime = 0;
      }
    },
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};
