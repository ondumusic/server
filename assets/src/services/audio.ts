import type { Track, UUID } from "../types";

interface AudioEvent {
  duration: number;
  currentTime: number;
  progressPercentage: number;
  isPlaying: boolean;
}

type AudioEventName = "timeupdate" | "ended";
type AudioEventHandler = (event: AudioEvent) => void;
type AudioEventUnsubscriber = () => void;

export class AudioService {
  #audioRefs: Map<UUID, HTMLAudioElement> = new Map();
  #eventListeners: Map<AudioEventName, Set<AudioEventHandler>> = new Map();
  #useTranscode: boolean = false;
  #currentTrack?: Track;
  #playToken?: string;

  destroy() {
    this.stop();
  }

  stop() {
    this.#currentTrack = undefined;
    this.#audioRefs.forEach((ref, trackId) => {
      this.#audioRefs.delete(trackId);
      ref.pause();
    });
  }

  setPlayToken(playToken: string) {
    this.#playToken = playToken;
  }

  play(track: Track) {
    const currentRef = this.#getCurrentAudioRef();
    if (currentRef) {
      currentRef.pause();
    }

    const audioRef = this.#getAudioRef(track);
    const transcode = this.#useTranscode ? "1" : "0";
    const streamUrl = `${track.streamUrl}?transcode=${transcode}&token=${this.#playToken}`;

    // if has track preloaded crossfade to new track?
    // otherwise just stop all current audiorefs and start new one

    this.#currentTrack = track;

    audioRef.src = streamUrl;
    audioRef.load();
    audioRef.volume = 1;

    if (audioRef.readyState >= 3) {
      audioRef.play();
    } else {
      const canPlay = () => {
        audioRef.play();
        audioRef.removeEventListener("canplay", canPlay);
      };

      audioRef.addEventListener("canplay", canPlay);
    }
  }

  preload(track: Track) {
    const audioRef = this.#getAudioRef(track);
    const streamUrl = `${track.streamUrl}?transcode=0&token=${this.#playToken}`;
    audioRef.src = streamUrl;
    audioRef.load();
    audioRef.volume = 1;
  }

  resume() {
    const audioRef = this.#getCurrentAudioRef();
    if (!audioRef) return;
    audioRef.play();
  }

  pause() {
    const audioRef = this.#getCurrentAudioRef();
    if (!audioRef) return;
    audioRef.pause();
  }

  scrubTo(updatedTime: number, forcePlay: boolean = false) {
    const audioRef = this.#getCurrentAudioRef();
    if (!audioRef) return;

    audioRef.currentTime = Math.max(
      0,
      Math.min(updatedTime, audioRef.duration || 0),
    );
    if (forcePlay === true) this.resume();
  }

  get isPlaying() {
    const audioRef = this.#getCurrentAudioRef();
    if (!audioRef) return false;
    return !audioRef.paused && !audioRef.ended;
  }

  #getCurrentAudioRef() {
    if (!this.#currentTrack) return;
    return this.#audioRefs.get(this.#currentTrack.id);
  }

  #getAudioRef(track: Track): HTMLAudioElement {
    let audioRef = this.#audioRefs.get(track.id);
    if (!audioRef) {
      audioRef = new Audio();
      audioRef.addEventListener("timeupdate", (e) => this.#emitStateChange(e));
      audioRef.addEventListener("ended", (e) => this.#emitStateChange(e));
      audioRef.addEventListener("play", (e) => this.#emitStateChange(e));
      audioRef.addEventListener("pause", (e) => this.#emitStateChange(e));
      audioRef.addEventListener("loadedmetadata", (e) =>
        this.#emitStateChange(e),
      );
      audioRef.addEventListener("durationchange", (e) =>
        this.#emitStateChange(e),
      );
      this.#audioRefs.set(track.id, audioRef);
    }

    return audioRef;
  }

  #emitStateChange(event: Event) {
    const audioRef = this.#getCurrentAudioRef();
    if (audioRef !== event.target) return;

    let progressPercentage = (audioRef.currentTime / audioRef.duration) * 100;
    if (Number.isNaN(progressPercentage)) progressPercentage = 0;

    const audioEvent: AudioEvent = {
      duration: audioRef.duration,
      currentTime: audioRef.currentTime,
      progressPercentage,
      isPlaying: !audioRef.paused && !audioRef.ended,
    };

    this.#emit("timeupdate", audioEvent);

    if (event.type === "ended") {
      this.#emit("ended", { ...audioEvent, isPlaying: false });
    }
  }

  #emit(name: AudioEventName, event: AudioEvent) {
    const listeners = this.#eventListeners.get(name) || new Set();
    listeners.forEach((listener) => {
      listener(event);
    });
  }

  on(
    name: AudioEventName,
    callback: AudioEventHandler,
  ): AudioEventUnsubscriber {
    const currentHandlers = this.#eventListeners.get(name) || new Set();
    currentHandlers.add(callback);
    this.#eventListeners.set(name, currentHandlers);

    return () => {
      const currentHandlers = this.#eventListeners.get(name) || new Set();
      currentHandlers.delete(callback);
      this.#eventListeners.set(name, currentHandlers);
    };
  }
}
