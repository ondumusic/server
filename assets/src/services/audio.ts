import { authApi } from "../api";
import type { Track } from "../types";

interface AudioEvent {
  duration: number;
  currentTime: number;
  progressPercentage: number;
  isPlaying: boolean;
}

interface AudioTrack extends Track {
  queueIndex: number;
  transcode?: boolean;
}

type AudioEventName = "timeupdate" | "ended";
type AudioEventHandler = (event: AudioEvent) => void;
type AudioEventUnsubscriber = () => void;

export class AudioService {
  #audioRef: HTMLAudioElement;
  #eventListeners: Map<AudioEventName, Set<AudioEventHandler>> = new Map();
  #currentTrack?: AudioTrack;
  #playToken?: string;
  #playTokenFetchedAt?: Date;
  #playTokenMaxAge: number = 1800 * 1000;
  #endedTimer?: ReturnType<typeof setTimeout>;

  constructor() {
    this.#audioRef = new Audio();
    this.#audioRef.preload = "auto";
    this.#audioRef.addEventListener("timeupdate", this.#emitStateChange);
    this.#audioRef.addEventListener("ended", this.#emitStateChange);
    this.#audioRef.addEventListener("play", this.#emitStateChange);
    this.#audioRef.addEventListener("pause", this.#emitStateChange);
    this.#audioRef.addEventListener("play", this.#handlePlayEvent);
    this.#audioRef.addEventListener("pause", this.#handlePauseEvent);

    this.#refreshPlayToken();
  }

  destroy() {
    this.stop();
    this.#eventListeners = new Map();

    this.#audioRef.removeEventListener("timeupdate", this.#emitStateChange);
    this.#audioRef.removeEventListener("ended", this.#emitStateChange);
    this.#audioRef.removeEventListener("play", this.#emitStateChange);
    this.#audioRef.removeEventListener("pause", this.#emitStateChange);
    this.#audioRef.removeEventListener("play", this.#handlePlayEvent);
    this.#audioRef.removeEventListener("pause", this.#handlePauseEvent);
    this.#audioRef.onerror = null;
    this.#audioRef.src = "";
  }

  stop() {
    this.#currentTrack = undefined;
    clearTimeout(this.#endedTimer);
    this.#audioRef.pause();
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

  async play(audioTrack: AudioTrack) {
    await this.#refreshPlayToken();

    this.#log("play", audioTrack.id);

    const isCurrentTrack =
      this.#currentTrack?.id === audioTrack.id &&
      this.#currentTrack?.queueIndex === audioTrack.queueIndex;

    if (isCurrentTrack) {
      this.scrubTo(0, true);
      return;
    }

    this.#currentTrack = audioTrack;
    this.#setSource(audioTrack);

    this.#audioRef.volume = 1;

    if (this.#audioRef.readyState >= 3) {
      this.#audioRef.play().catch((err) => console.warn("blocked:", err.name));
    } else {
      const canPlay = () => {
        this.#audioRef
          .play()
          .catch((err) => console.warn("blocked:", err.name));
        this.#audioRef.removeEventListener("canplay", canPlay);
        this.#audioRef.onerror = null;
      };
      this.#audioRef.addEventListener("canplay", canPlay);
    }
  }

  resume() {
    this.#audioRef.play().catch((err) => console.warn("blocked:", err.name));
  }

  pause() {
    this.#audioRef.pause();
  }

  scrubTo(updatedTime: number, forcePlay: boolean = false) {
    let duration = this.#audioRef.duration || 0;
    if (Number.isNaN(duration)) duration = 0;
    this.#audioRef.currentTime = Math.max(0, Math.min(updatedTime, duration));

    this.#monitorEnded();

    if (forcePlay === true) this.resume();
  }

  get isPlaying() {
    return !this.#audioRef.paused && !this.#audioRef.ended;
  }

  #setSource(audioTrack: AudioTrack) {
    const sources =
      audioTrack.transcode === true
        ? [`${audioTrack.streamUrl}?transcode=1&token=${this.#playToken}`]
        : [
            `${audioTrack.streamUrl}?transcode=0&token=${this.#playToken}`,
            `${audioTrack.streamUrl}?transcode=1&token=${this.#playToken}`,
          ];

    this.#audioRef.src = sources[0];
    this.#audioRef.load();

    if (sources.length === 1) return;

    let sourceIndex = 0;
    const nextSource = () => {
      // MEDIA_ERR_ABORTED || MEDIA_ERR_NETWORK
      if (
        this.#audioRef.error?.code === 1 ||
        this.#audioRef.error?.code === 12
      ) {
        this.#audioRef.onerror = null;
        this.#log("audio aborted");
        return;
      }

      if (sourceIndex >= sources.length) {
        this.#audioRef.onerror = null;
        this.#log("no sources left");
        return;
      }

      this.#audioRef.src = sources[++sourceIndex];
      this.#audioRef.load();
    };

    this.#audioRef.onerror = nextSource;
  }

  // In some scenarios (mostly related to live transcoding) the ended event
  // was not triggered properly. This is why we also add a monitor to force
  // "end" it when it should have ended.
  #monitorEnded() {
    clearTimeout(this.#endedTimer);
    this.#endedTimer = undefined;

    const trackId = this.#currentTrack?.id;
    const queueIndex = this.#currentTrack?.queueIndex;

    const startMonitor = () => {
      if (
        this.#currentTrack?.id !== trackId ||
        this.#currentTrack?.queueIndex !== queueIndex
      ) {
        return;
      }

      const duration = this.#audioRef.duration;
      if (!Number.isFinite(duration) || duration <= 0) return;

      const remaining = (duration - this.#audioRef.currentTime) * 1000;
      if (remaining <= 0) return;

      clearTimeout(this.#endedTimer);
      this.#endedTimer = setTimeout(() => {
        if (
          this.#currentTrack?.id !== trackId ||
          this.#currentTrack?.queueIndex !== queueIndex
        ) {
          return;
        }
        this.#log("monitoring ended");
        this.#endedTimer = undefined;
        this.#emitEnded();
      }, remaining + 500);

      this.#log("started monitoring for ended", {
        trackId,
        remaining: remaining + 500,
      });
    };

    if (this.#audioRef.readyState >= 1) {
      startMonitor();
    } else {
      const onMetadata = () => {
        this.#audioRef.removeEventListener("loadedmetadata", onMetadata);
        startMonitor();
      };
      this.#audioRef.addEventListener("loadedmetadata", onMetadata);
    }
  }

  #handlePlayEvent = () => {
    this.#log("play event", { currentTrackId: this.#currentTrack?.id });
    this.#monitorEnded();
  };

  #handlePauseEvent = () => {
    this.#log("pause event");
    clearTimeout(this.#endedTimer);
    this.#endedTimer = undefined;
  };

  #emitStateChange = (event: Event) => {
    if (this.#audioRef.readyState < 3) return;

    let duration = this.#audioRef.duration || 0;
    if (Number.isNaN(duration)) duration = 0;

    let progressPercentage = (this.#audioRef.currentTime / duration) * 100;
    if (Number.isNaN(progressPercentage)) progressPercentage = 0;

    const audioEvent: AudioEvent = {
      currentTime: this.#audioRef.currentTime,
      duration,
      progressPercentage,
      isPlaying: !this.#audioRef.paused && !this.#audioRef.ended,
    };

    this.#emit("timeupdate", audioEvent);

    if (event.type === "ended") {
      this.#log("event ended");
      clearTimeout(this.#endedTimer);
      this.#emitEnded();
    }
  };

  #emitEnded() {
    const duration = Number.isFinite(this.#audioRef.duration)
      ? this.#audioRef.duration
      : 0;
    const currentTime = this.#audioRef.currentTime || 0;
    let progressPercentage = duration > 0 ? (currentTime / duration) * 100 : 0;
    if (Number.isNaN(progressPercentage)) progressPercentage = 0;

    this.#emit("ended", {
      duration,
      currentTime,
      progressPercentage,
      isPlaying: !this.#audioRef.paused && !this.#audioRef.ended,
    });
  }

  #emit(name: AudioEventName, event: AudioEvent) {
    const listeners = this.#eventListeners.get(name) || new Set();
    listeners.forEach((listener) => {
      listener(event);
    });
  }

  async #refreshPlayToken() {
    let needsRefresh = !this.#playToken;
    if (!needsRefresh && this.#playTokenFetchedAt) {
      needsRefresh =
        Date.now() - this.#playTokenFetchedAt.getTime() > this.#playTokenMaxAge;
    }

    if (needsRefresh) {
      const response = await authApi.getPlayToken();
      if (response.ok) {
        this.#playToken = response.playToken;
        this.#playTokenFetchedAt = new Date();
      } else {
        this.#playToken = undefined;
      }
    }

    return this.#playToken;
  }

  #log(...args: unknown[]): void {
    if (import.meta.env.MODE === "dev") {
      console.log(...args);
    }
  }
}
