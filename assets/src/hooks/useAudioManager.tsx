import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { usePlayer } from "../hooks/usePlayer";

export interface AudioManagerContext {
  scrubTo(updatedTime: number): void;
  scrubAndPlay(updatedTime: number): void;
}

const AudioManagerContext = createContext<AudioManagerContext>({
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
  const audioRef = useRef<AudioContext>(new AudioContext());
  const sourceRef = useRef<AudioBufferSourceNode>(null);
  const abortRef = useRef<AbortController>(null);
  const pollRef = useRef<number>(null);
  const startTimeRef = useRef<number>(null);
  const bufferRef = useRef<AudioBuffer>(null);
  const [isPolling, setIsPolling] = useState(false);
  const { isPlaying, currentTrack, nextTrack, setDuration, setCurrentTime } =
    usePlayer();

  // currentTime polling
  useEffect(() => {
    if (pollRef.current) cancelAnimationFrame(pollRef.current);
    if (!isPolling || !currentTrack || !isPlaying) return;

    // Poll function to get the current playback position
    const pollCurrentTime = () => {
      if (audioRef.current && startTimeRef.current !== null) {
        const currentTime = audioRef.current.currentTime - startTimeRef.current;
        setCurrentTime(currentTime);
      }

      pollRef.current = requestAnimationFrame(pollCurrentTime);
      return () => {
        if (pollRef.current) cancelAnimationFrame(pollRef.current);
      };
    };

    pollCurrentTime();
  }, [currentTrack, isPlaying, isPolling, setCurrentTime]);

  // Pause/resume functionality
  useEffect(() => {
    if (!audioRef.current) return;

    if (!isPlaying && audioRef.current.state === "running") {
      audioRef.current.suspend();
      setIsPolling(false);
    } else if (isPlaying) {
      audioRef.current.resume();
      setIsPolling(true);
    }
  }, [isPlaying]);

  const cleanupSourceNode = (sourceNode: AudioBufferSourceNode) => {
    sourceNode.disconnect();
    sourceNode.removeEventListener("ended", nextTrack);
    sourceNode.stop(0);
  };

  // Scrubbing/seeking functionality
  const scrubTo = (updatedTime: number, continuePlayback: boolean = false) => {
    if (!audioRef.current || !bufferRef.current) return;

    // Cleanup the previous source node
    if (sourceRef.current) cleanupSourceNode(sourceRef.current);

    // Create new source node
    sourceRef.current = audioRef.current.createBufferSource();
    sourceRef.current.buffer = bufferRef.current;
    sourceRef.current.connect(audioRef.current.destination);

    // If we are continuing playback assign the events and ensure
    // polling is enabled again
    if (continuePlayback) {
      sourceRef.current.addEventListener("ended", nextTrack);
      setIsPolling(true);
    }

    // Scrub and preview, or continue playback
    if (continuePlayback) {
      sourceRef.current.start(0, updatedTime);
    } else {
      sourceRef.current.start(0, updatedTime, 0.1);
    }

    // If the state is suspended, attempt to resume
    if (audioRef.current.state === "suspended") {
      audioRef.current.resume();
    }

    // Update the startTime ref and currentTime state
    startTimeRef.current = audioRef.current.currentTime - updatedTime;
    setCurrentTime(updatedTime);
  };

  // Everything AudioContext (fetch, play, etc)
  // biome-ignore lint/correctness/useExhaustiveDependencies(cleanupSourceNode): suppress dependency cleanupSourceNode
  // biome-ignore lint/correctness/useExhaustiveDependencies(setCurrentTime): suppress dependency setCurrentTime
  // biome-ignore lint/correctness/useExhaustiveDependencies(scrubTo): suppress dependency scrubTo
  useEffect(() => {
    if (!currentTrack) return;

    // If a fetch is still in progress we can abort it.
    if (abortRef.current) {
      abortRef.current.abort();
    }

    // If we are switching songs we should disconnect and stop the current
    // source (if one is available)
    if (sourceRef.current) cleanupSourceNode(sourceRef.current);

    // Setup a new abort controller
    abortRef.current = new AbortController();

    // Reset initial states
    setIsPolling(false);
    setCurrentTime(0);
    setDuration(0);

    // Get the song
    fetch(`/stream/${currentTrack.id}`, {
      signal: abortRef.current.signal,
    })
      .then((resp) => resp.arrayBuffer())
      .then((buf) => {
        if (abortRef.current?.signal.aborted) return;
        return audioRef.current?.decodeAudioData(buf);
      })
      .then((audioBuf) => {
        if (!audioBuf) return;
        if (abortRef.current?.signal.aborted) return;
        if (!audioRef.current) return;

        bufferRef.current = audioBuf;
        startTimeRef.current = audioRef.current.currentTime;
        setDuration(audioBuf.duration);
        setIsPolling(true);
        scrubTo(0, true);
      })
      .catch(console.error);
  }, [currentTrack, setDuration]);

  const value = {
    scrubTo,
    scrubAndPlay(updatedTime: number) {
      scrubTo(updatedTime, true);
    },
  };

  return (
    <AudioManagerContext.Provider value={value}>
      {children}
    </AudioManagerContext.Provider>
  );
};
