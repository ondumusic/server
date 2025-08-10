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
import type { Album, Song } from "../types";
import { findCachedItem } from "../utils/findCachedItem";

export interface PlayerContextT {
  audioRef: RefObject<HTMLAudioElement | null>;
  isVisible: boolean;

  // Current queue and song information
  queue: Song[];
  hasPrevSong: boolean;
  hasNextSong: boolean;
  isPlaying: boolean;
  currentSong?: Song;
  currentTime: number;
  duration: number;
  progressPercentage: number;

  // State Management
  setCurrentTime(currentTime: number): void;
  setDuration(duration: number): void;
  setIsPlaying(isPlaying: boolean): void;
  setIsVisible(isVisible: boolean): void;

  // Queue Management
  prevSong(): void;
  nextSong(): void;
  enqueueAndPlay(songs: Song[], startWithSong?: Song): void;
}

const PlayerContext = createContext<PlayerContextT>({
  audioRef: { current: null },
  isVisible: false,
  queue: [],
  hasPrevSong: false,
  hasNextSong: false,
  isPlaying: false,
  currentSong: undefined,
  currentTime: 0,
  duration: 0,
  progressPercentage: 0,
  setCurrentTime: (_currentTime) => {},
  setDuration: (_duration) => {},
  setIsPlaying: (_isPlaying) => {},
  setIsVisible: (_isVisible) => {},
  prevSong: () => {},
  nextSong: () => {},
  enqueueAndPlay: (_songs, _startWithSong?) => {},
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
    currentSong,
    replaceQueue,
    prevSong,
    nextSong,
    hasPrevSong,
    hasNextSong,
  } = useQueue();

  const [isVisible, setIsVisible] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioRef = useRef<HTMLAudioElement>(null);

  // This effect controls the actual playback, for example to switch between
  // playing and paused states. If there is no (more) song and it is set to
  // isPlaying it will set the player into a paused state.
  useEffect(() => {
    if (!audioRef || !audioRef.current) return;

    if (isPlaying && !currentSong) {
      setIsPlaying(false);
    } else if (isPlaying) {
      audioRef.current.play();
    } else {
      audioRef.current.pause();
    }
  }, [isPlaying, currentSong]);

  // When the currentSong changes we assume we are starting from 0 again so
  // reset to 0 and the audio event handlers will update it once metadata is
  // loaded and it starts playing.
  useEffect(() => {
    if (!currentSong) return;
    setDuration(0);
    setCurrentTime(0);
  }, [currentSong]);

  const currentAlbum: Album | undefined = useMemo(() => {
    if (!currentSong) return undefined;
    return findCachedItem<Album>(
      ["albumList", currentSong?.albumArtistId],
      currentSong?.albumId,
    );
  }, [currentSong]);

  // Experimenting with MediaSession
  useEffect(() => {
    if (!currentSong) {
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
        title: currentSong?.name,
        artist: currentSong?.artist?.name,
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
        if (hasPrevSong) prevSong();
        else setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("nexttrack", () => {
        if (hasNextSong) nextSong();
        else setIsPlaying(false);
      });
    }
  }, [hasNextSong, hasPrevSong, nextSong, prevSong, currentSong, currentAlbum]);

  // Calculate the current playback percentage
  let progressPercentage = (currentTime / duration) * 100;
  if (Number.isNaN(progressPercentage)) progressPercentage = 0;

  const value = {
    audioRef,
    isVisible,

    // Current queue and song information
    queue,
    hasPrevSong,
    hasNextSong,
    isPlaying,
    currentSong,
    currentTime,
    duration,
    progressPercentage,

    // State Management
    setCurrentTime,
    setDuration,
    setIsPlaying,
    setIsVisible,

    // Queue Management
    prevSong,
    nextSong,
    enqueueAndPlay(songs: Song[], startWithSong?: Song) {
      if (!Array.isArray(songs)) songs = [songs];
      if (songs.length === 0) return;
      setIsVisible(true);
      replaceQueue(songs, startWithSong);
      if (!isPlaying) setIsPlaying(true);
    },
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
};
