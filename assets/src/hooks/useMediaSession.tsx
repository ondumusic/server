import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useState,
} from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { useQueue } from "../hooks/useQueue";
import { useAlbum } from "../library";

const MediaSessionContext = createContext({});

export function useMediaSession() {
  return useContext(MediaSessionContext);
}

const NavigatorMediaSessionProvider = ({ children }: PropsWithChildren) => {
  const { currentTrack, prevTrack, nextTrack } = useQueue();
  const { addTimeObserver, isPlaying, setIsPlaying, duration, scrubTo } =
    useAudioManager();
  const [currentTime, setCurrentTime] = useState(0);

  useEffect(() => {
    const unsubscribe = addTimeObserver(({ currentTime }) =>
      setCurrentTime(currentTime),
    );
    return unsubscribe;
  }, [addTimeObserver]);

  const { data: currentAlbum } = useAlbum(currentTrack?.albumId);

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
  // biome-ignore lint/correctness/useExhaustiveDependencies(scrubTo): suppress dependency scrubTo
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
      else scrubTo(0, true);
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
