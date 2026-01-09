import {
  createContext,
  type PropsWithChildren,
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

const NavigatorMediaSessionProvider = ({ children }: PropsWithChildren) => {
  const { currentTrack, prevTrack, nextTrack } = useQueue();
  const { isPlaying, setIsPlaying, currentTime, duration, scrubAndPlay } =
    useAudioManager();

  // Find the currentAlbum from cache so we can display it in the mediaSession
  const currentAlbum: Album | undefined = useMemo(() => {
    if (!currentTrack) return undefined;
    return findCachedItem<Album>(
      ["albumList", currentTrack?.albumArtistId],
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
      position: Math.max(0, Math.min(duration, currentTime)),
    });
  }, [isPlaying, currentTrack, currentTime]);

  // Setup the mediaSession Metadata
  useEffect(() => {
    if (!currentTrack) {
      navigator.mediaSession.metadata = null;
    } else {
      const artwork = [];
      if (currentAlbum?.artworkUrl) {
        artwork.push({ src: currentAlbum.artworkUrl });
      }

      navigator.mediaSession.metadata = new MediaMetadata({
        title: currentTrack?.name,
        artist: currentTrack?.artist?.name,
        album: currentAlbum?.name,
        artwork,
      });
    }
  }, [currentTrack, currentAlbum]);

  // Setup the mediaSession Action Handlers
  // biome-ignore lint/correctness/useExhaustiveDependencies(setIsPlaying): suppress dependency setIsPlaying
  // biome-ignore lint/correctness/useExhaustiveDependencies(scrubAndPlay): suppress dependency scrubAndPlay
  // biome-ignore lint/correctness/useExhaustiveDependencies(prevTrack): suppress dependency prevTrack
  // biome-ignore lint/correctness/useExhaustiveDependencies(nextTrack): suppress dependency nextTrack
  useEffect(() => {
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
      if (currentTime <= 2) prevTrack();
      else scrubAndPlay(0);
    });

    navigator.mediaSession.setActionHandler("nexttrack", () => {
      console.log("nexttrack");
      nextTrack();
    });
  }, [currentTime]);

  const value = {};
  return (
    <MediaSessionContext.Provider value={value}>
      {children}
    </MediaSessionContext.Provider>
  );
};

const UnsupportedMediaSessionProvider = ({ children }: PropsWithChildren) => {
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
