import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useMemo,
} from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import type { Album } from "../types";
import { findCachedItem } from "../utils/findCachedItem";

const MediaSessionContext = createContext({});

export function useMediaSession() {
  return useContext(MediaSessionContext);
}

interface Props {
  children: ReactNode;
}

const NavigatorMediaSessionProvider = ({ children }: Props) => {
  const { currentTrack, prevTrack, nextTrack, hasNextTrack, hasPrevTrack } =
    useQueue();
  const { isPlaying, setIsPlaying, currentTime, duration } = useAudioManager();

  // Find the currentAlbum from cache so we can display it in the mediaSession
  const currentAlbum: Album | undefined = useMemo(() => {
    if (!currentTrack) return undefined;
    return findCachedItem<Album>(
      ["albumList", currentTrack?.artistId],
      currentTrack?.albumId,
    );
  }, [currentTrack]);

  // Set the mediaSession Position State
  // biome-ignore lint/correctness/useExhaustiveDependencies(duration): suppress dependency duration
  useEffect(() => {
    if (!currentTrack || duration === 0) return;
    if (!isPlaying) return;

    navigator.mediaSession.setPositionState({
      playbackRate: 1,
      duration,
      position: currentTime,
    });
  }, [isPlaying, currentTrack, currentTime]);

  // Setup the mediaSession Metadata
  useEffect(() => {
    if (!currentTrack) {
      navigator.mediaSession.metadata = null;
    } else {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: currentTrack?.name,
        artist: currentTrack?.artist?.name,
        album: currentAlbum?.name,
        artwork: [],
      });
    }
  }, [currentTrack, currentAlbum]);

  // Setup the mediaSession Action Handlers
  // biome-ignore lint/correctness/useExhaustiveDependencies(setIsPlaying): suppress dependency setIsPlaying
  // biome-ignore lint/correctness/useExhaustiveDependencies(prevTrack): suppress dependency prevTrack
  // biome-ignore lint/correctness/useExhaustiveDependencies(nextTrack): suppress dependency nextTrack
  useEffect(() => {
    if (!currentTrack) {
      navigator.mediaSession.setActionHandler("play", null);
      navigator.mediaSession.setActionHandler("pause", null);
      navigator.mediaSession.setActionHandler("stop", null);
      navigator.mediaSession.setActionHandler("previoustrack", null);
      navigator.mediaSession.setActionHandler("nexttrack", null);
      navigator.mediaSession.setActionHandler("seekbackward", null);
      navigator.mediaSession.setActionHandler("seekforward", null);
      navigator.mediaSession.setActionHandler("seekto", null);
    } else {
      navigator.mediaSession.setActionHandler("play", () => {
        console.log("play");
        setIsPlaying(true);
      });

      navigator.mediaSession.setActionHandler("pause", () => {
        console.log("pause");
        setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("stop", () => {
        console.log("stop");
        setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("previoustrack", () => {
        console.log("previoustrack");
        if (hasPrevTrack) prevTrack();
        else setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("nexttrack", () => {
        console.log("nexttrack");
        if (hasNextTrack) nextTrack();
        else setIsPlaying(false);
      });

      navigator.mediaSession.setActionHandler("seekbackward", (details) => {
        // TODO: This does not appear to be called (Safari, macOS)
        console.log("seekbackward", details.seekOffset || 15);
      });

      navigator.mediaSession.setActionHandler("seekforward", (details) => {
        // TODO: This does not appear to be called (Safari, macOS)
        console.log("seekforward", details.seekOffset || 15);
      });

      navigator.mediaSession.setActionHandler("seekto", (details) => {
        // TODO: This does not appear to be called (Safari, macOS)
        console.log("seekto", details.fastSeek, details.seekTime);
      });
    }
  }, [hasNextTrack, hasPrevTrack, currentTrack]);

  const value = {};
  return (
    <MediaSessionContext.Provider value={value}>
      {children}
    </MediaSessionContext.Provider>
  );
};

const UnsupportedMediaSessionProvider = ({ children }: Props) => {
  const value = {};
  return (
    <MediaSessionContext.Provider value={value}>
      {children}
    </MediaSessionContext.Provider>
  );
};

// Provider export depends on navigator support for mediaSession
export const MediaSessionProvider =
  "mediaSession" in navigator
    ? NavigatorMediaSessionProvider
    : UnsupportedMediaSessionProvider;
