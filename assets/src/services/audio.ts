import type { Track, UUID } from "../types";

// TODO: Maybe make this configurable for user? Per album/track?
const CROSSFADE_DURATION = 1000; // ms

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
  #audioRefs: Map<UUID, HTMLAudioElement> = new Map();
  #eventListeners: Map<AudioEventName, Set<AudioEventHandler>> = new Map();
  #currentTrack?: AudioTrack;
  #preloadedTrack?: AudioTrack;
  #playToken?: string;
  #endedTimer?: ReturnType<typeof setTimeout>;
  #fadeTimer?: ReturnType<typeof requestAnimationFrame>;
  #isFading: boolean = false;

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

  setPlayToken(playToken: string) {
    this.#playToken = playToken;
  }

  play(audioTrack: AudioTrack) {
    this.#log("play", audioTrack.id);

    const isCurrentTrack =
      this.#currentTrack?.id === audioTrack.id &&
      this.#currentTrack?.queueIndex === audioTrack.queueIndex;

    const isPreloadedTrack =
      this.#preloadedTrack?.id === audioTrack.id &&
      this.#preloadedTrack?.queueIndex === audioTrack.queueIndex;

    let stopPlayback = true;
    if (this.#isFading && (isCurrentTrack || isPreloadedTrack)) {
      stopPlayback = false;
    }

    this.#log({
      isFading: this.#isFading,
      isCurrentTrack,
      isPreloadedTrack,
      stopPlayback,
    });

    // If we are fading the fade will already start playing the song.
    if (!stopPlayback && this.#isFading) {
      this.#log("ignoring play() because already crossfading to this track");
      return;
    }

    // If there is current playback and we are not fading to this song we can
    // stop the playback (pause, mute).
    const currentRef = this.#getCurrentAudioRef();
    if (currentRef && stopPlayback) {
      currentRef.pause();
      currentRef.volume = 0;
    }

    // At this point there should not be any crossfade active anymore
    this.#stopCrossfade();

    // Get audio reference for this track
    const audioRef = this.#getAudioRef(audioTrack);

    // If we want to play the same track we can just rewind.
    if (this.#currentTrack?.id === audioTrack.id) {
      this.scrubTo(0, true);
      return;
    }

    // Make sure the previous audio element doesn't call onerror event.
    if (currentRef) {
      currentRef.onerror = null;
    }

    // Set currenTrack to the new Track
    this.#currentTrack = audioTrack;

    // Load the track
    this.#setSource(audioRef, audioTrack);

    audioRef.load();
    audioRef.volume = 1;

    // If readyState is 3 (HAVE_FUTURE_DATA) or higher (4: HAVE_ENOUGH_DATA)
    // we should be able to play immediately.
    if (audioRef.readyState >= 3) {
      audioRef.play();
    } else {
      // Otherwise we'll autoplay when the canplay event is dispatched.
      const canPlay = () => {
        audioRef.play();
        audioRef.removeEventListener("canplay", canPlay);
        audioRef.onerror = null;
      };

      audioRef.addEventListener("canplay", canPlay);
    }

    // Cleanup any old unused audio refs.
    this.#cleanupRefs();
  }

  preload(audioTrack: AudioTrack) {
    if (this.#currentTrack?.id === audioTrack.id) {
      this.#log("not preloading; same as currentTrack");
      return;
    }

    if (this.#preloadedTrack?.id === audioTrack.id) {
      this.#log("already preloaded");
      return;
    }

    this.#log("preload", audioTrack.id);
    const audioRef = this.#getAudioRef(audioTrack);
    this.#setSource(audioRef, audioTrack);
    audioRef.load();
    audioRef.volume = 0;

    this.#preloadedTrack = audioTrack;
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

    let duration = audioRef.duration || 0;
    if (Number.isNaN(duration)) duration = 0;
    audioRef.currentTime = Math.max(0, Math.min(updatedTime, duration));

    if (forcePlay === true) this.resume();
  }

  get isPlaying() {
    const audioRef = this.#getCurrentAudioRef();
    if (!audioRef) return false;
    return !audioRef.paused && !audioRef.ended;
  }

  #setSource(audioRef: HTMLAudioElement, audioTrack: AudioTrack) {
    const sources =
      audioTrack.transcode === true
        ? [`${audioTrack.streamUrl}?transcode=1&token=${this.#playToken}`]
        : [
            `${audioTrack.streamUrl}?transcode=0&token=${this.#playToken}`,
            `${audioTrack.streamUrl}?transcode=1&token=${this.#playToken}`,
          ];

    audioRef.src = sources[0];

    if (sources.length === 1) return;

    let sourceIndex = 0;
    const nextSource = () => {
      // MEDIA_ERR_ABORTED || MEDIA_ERR_NETWORK
      if (audioRef.error?.code === 1 || audioRef.error?.code === 12) {
        audioRef.onerror = null;
        this.#log("audio aborted");
        return;
      }

      this.#log("source failed, attempting next source");

      if (sourceIndex >= sources.length) {
        audioRef.onerror = null;
        this.#log("no sources left");
        return;
      }

      audioRef.src = sources[++sourceIndex];
      audioRef.load();
    };

    audioRef.onerror = nextSource;
  }

  #getCurrentAudioRef() {
    if (!this.#currentTrack) return;
    return this.#audioRefs.get(this.#currentTrack.id);
  }

  #getAudioRef(audioTrack: AudioTrack): HTMLAudioElement {
    let audioRef = this.#audioRefs.get(audioTrack.id);
    if (!audioRef) {
      audioRef = new Audio();
      audioRef.addEventListener("timeupdate", this.#emitStateChange);
      audioRef.addEventListener("ended", this.#emitStateChange);
      audioRef.addEventListener("play", this.#emitStateChange);
      audioRef.addEventListener("pause", this.#emitStateChange);
      this.#audioRefs.set(audioTrack.id, audioRef);
    }

    return audioRef;
  }

  #emitStateChange = (event: Event) => {
    const audioRef = this.#getCurrentAudioRef();
    if (audioRef !== event.target) return;
    if (audioRef.readyState < 3) return;

    let duration = audioRef.duration || 0;
    if (Number.isNaN(duration)) duration = 0;

    let progressPercentage = (audioRef.currentTime / duration) * 100;
    if (Number.isNaN(progressPercentage)) progressPercentage = 0;

    const audioEvent: AudioEvent = {
      currentTime: audioRef.currentTime,
      duration,
      progressPercentage,
      isPlaying: this.isPlaying,
    };

    this.#emit("timeupdate", audioEvent);

    if (event.type === "ended") {
      if (this.#isFading) return;
      this.#log("event ended");
      clearTimeout(this.#endedTimer);
      this.#emitEnded();
    }

    if (event.type === "timeupdate") {
      // Set the endedTimer because sometimes (mostly when transcoding) there
      // are potential issues resulting in the ended event not being sent.
      if (audioEvent.duration - audioEvent.currentTime < 0.2) {
        clearTimeout(this.#endedTimer);
        this.#endedTimer = setTimeout(() => {
          if (this.#isFading) return;
          this.#log("timer ended");
          this.#emitEnded();
        }, 200);
      }

      if (
        audioEvent.duration - audioEvent.currentTime <=
        CROSSFADE_DURATION / 1000
      ) {
        this.#log("should crossfade");
        this.#crossfade(this.#preloadedTrack);
      }
    }

    return event;
  };

  #emitEnded() {
    const audioRef = this.#getCurrentAudioRef();
    if (!audioRef) return;

    let progressPercentage = (audioRef.currentTime / audioRef.duration) * 100;
    if (Number.isNaN(progressPercentage)) progressPercentage = 0;

    this.#emit("ended", {
      duration: audioRef.duration,
      currentTime: audioRef.currentTime,
      progressPercentage,
      isPlaying: !audioRef.paused && !audioRef.ended,
    });
  }

  #emit(name: AudioEventName, event: AudioEvent) {
    const listeners = this.#eventListeners.get(name) || new Set();
    listeners.forEach((listener) => {
      listener(event);
    });
  }

  #crossfade(to?: AudioTrack) {
    if (this.#isFading) {
      this.#log("already fading");
      return;
    }

    if (!to) {
      this.#log("not crossfading; no preloadedTrack");
      return;
    }

    this.#stopCrossfade();

    if (this.#currentTrack?.id === to.id) {
      this.#log("not crossfading; same as currenTrack");
      return;
    }

    this.#isFading = true;

    const currentRef = this.#getCurrentAudioRef();
    const nextRef = this.#getAudioRef(to);
    if (!currentRef) return;

    // Start next track at 0 volume to avoid pop
    nextRef.volume = 0;
    nextRef.play();

    const startTime = performance.now();
    let endedLastTrack = false;

    const fade = () => {
      const elapsed = performance.now() - startTime;
      const progress = Math.min(elapsed / CROSSFADE_DURATION, 1);

      // Use equal-power crossfade curve for smoother transition
      const fadeOut = Math.cos(progress * Math.PI * 0.5);
      const fadeIn = Math.sin(progress * Math.PI * 0.5);

      currentRef.volume = fadeOut;
      nextRef.volume = fadeIn;

      if (progress >= 0.3 && progress <= 0.6) {
        if (!endedLastTrack) {
          endedLastTrack = true;
          clearTimeout(this.#endedTimer);
          this.#currentTrack = to;
          this.#preloadedTrack = undefined;
          this.#emitEnded();
        }
      }

      if (progress < 1) {
        this.#fadeTimer = requestAnimationFrame(fade);
      } else {
        this.#isFading = false;

        currentRef.pause();
        currentRef.currentTime = 0;
        currentRef.volume = 1;

        this.#cleanupRefs();
      }
    };

    this.#fadeTimer = requestAnimationFrame(fade);
  }

  #stopCrossfade() {
    this.#log("stop crossfade");
    this.#isFading = false;
    if (this.#fadeTimer) cancelAnimationFrame(this.#fadeTimer);
  }

  #cleanupRefs() {
    const currentRef = this.#getCurrentAudioRef();

    this.#log("cleanup refs");
    this.#audioRefs.forEach((ref, trackId) => {
      if (ref === currentRef) return;

      this.#log("cleanup ref", trackId);
      this.#audioRefs.delete(trackId);

      ref.removeEventListener("timeupdate", this.#emitStateChange);
      ref.removeEventListener("ended", this.#emitStateChange);
      ref.removeEventListener("play", this.#emitStateChange);
      ref.removeEventListener("pause", this.#emitStateChange);

      ref.volume = 0;
      ref.src = "";
      ref.load();
    });

    this.#log("refs remaining:", this.#audioRefs);
  }

  #log(...args: unknown[]): void {
    if (import.meta.env.MODE === "dev") {
      console.log(...args);
    }
  }
}
