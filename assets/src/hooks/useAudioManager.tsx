import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { useQueue } from "../hooks/useQueue";
import { generateSilentTrack } from "../utils/generateSilentTrack";

export interface AudioManagerContext {
  isPlaying: boolean;
  duration: number;
  currentTime: number;

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
  setCurrentTime: (_currentTime) => {},
  setDuration: (_duration) => {},
  setIsPlaying: (_isPlaying) => {},
  scrubTo: (_updatedTime) => {},
  scrubAndPlay: (_updatedTime) => {},
});

export function useAudioManager() {
  return useContext(AudioManagerContext);
}

function createShadowAudioElement() {
  const audioEl = new Audio();
  audioEl.classList.add("hidden");
  // audioEl.classList.add("absolute", "top-0", "left-0");
  // audioEl.controls = true;
  document.body.appendChild(audioEl);
  return audioEl;
}

interface Props {
  children: ReactNode;
}

export const AudioManagerProvider = ({ children }: Props) => {
  const shadowRef = useRef<HTMLAudioElement>(null);
  const shadowBlobUrlRef = useRef<string>(null);
  const audioRef = useRef<AudioContext>(new AudioContext());
  const sourceRef = useRef<AudioBufferSourceNode>(null);
  const abortRef = useRef<AbortController>(null);
  const pollRef = useRef<number>(null);
  const startTimeRef = useRef<number>(null);
  const bufferRef = useRef<AudioBuffer>(null);
  const [isPolling, setIsPolling] = useState(false);

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const { currentTrack, nextTrack } = useQueue();

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
  }, [currentTrack, isPlaying, isPolling]);

  // Pause/resume functionality
  useEffect(() => {
    if (!audioRef.current || !shadowRef.current) return;

    if (!currentTrack || (!isPlaying && audioRef.current.state === "running")) {
      audioRef.current.suspend();
      shadowRef.current.pause();
      setIsPolling(false);
    } else if (isPlaying) {
      shadowRef.current.play();
      audioRef.current.resume();
      setIsPolling(true);
    }
  }, [isPlaying, currentTrack]);

  const cleanupSourceNode = (sourceNode: AudioBufferSourceNode) => {
    sourceNode.disconnect();
    sourceNode.removeEventListener("ended", nextTrack);
    sourceNode.stop(0);
  };

  // Scrubbing/seeking functionality
  const scrubTo = (updatedTime: number, continuePlayback: boolean = false) => {
    if (!audioRef.current || !bufferRef.current || !shadowRef.current) return;

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

    // Also update currentTime on the shadow audio element
    shadowRef.current.currentTime = updatedTime;

    // If the state is suspended, attempt to resume
    if (isPlaying && audioRef.current.state === "suspended") {
      audioRef.current.resume();
      shadowRef.current.play();
    }

    // Update the startTime ref and currentTime state
    startTimeRef.current = audioRef.current.currentTime - updatedTime;
    setCurrentTime(updatedTime);
  };

  // Everything AudioContext (fetch, play, etc)
  // biome-ignore lint/correctness/useExhaustiveDependencies(cleanupSourceNode): suppress dependency cleanupSourceNode
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
    if (shadowRef.current) shadowRef.current.remove();
    if (pollRef.current) cancelAnimationFrame(pollRef.current);
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

        if (!shadowRef.current) {
          shadowRef.current = createShadowAudioElement();
        }

        if (shadowBlobUrlRef.current) {
          URL.revokeObjectURL(shadowBlobUrlRef.current);
        }

        shadowBlobUrlRef.current = generateSilentTrack(
          audioBuf.duration,
          audioRef.current.sampleRate,
        );
        shadowRef.current.src = shadowBlobUrlRef.current;

        setDuration(audioBuf.duration);
        setCurrentTime(0);
        setIsPolling(true);
        scrubTo(0, true);
      })
      .catch(console.error);
  }, [currentTrack]);

  const value = {
    isPlaying,
    duration,
    currentTime,
    setCurrentTime,
    setDuration,
    setIsPlaying,

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
