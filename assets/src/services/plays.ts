import { type Play, playApi } from "../api/plays";
import { uuid } from "../utils/uuid";

const QUEUE_KEY = "pendingPlays";
const ENABLED_KEY = "recordPlays";
const MAX_BATCH_SIZE = 500;

interface CurrentPlay {
  trackId: string;
  duration?: number | null;
  playedAt: Date;
  listened: number;
  lastTime: number;
  recorded: boolean;
}

// Records a play once a track was played long enough, the same rules as
// Last.fm: tracks longer than 30 seconds, played for half their duration or 4
// minutes (whichever comes first). Plays that could not be sent are queued and
// sent again later.
export class PlayRecorder {
  #current?: CurrentPlay;
  #flushing = false;

  get enabled(): boolean {
    return localStorage.getItem(ENABLED_KEY) !== "false";
  }

  set enabled(enabled: boolean) {
    localStorage.setItem(ENABLED_KEY, String(enabled));
  }

  start(track: { id: string; duration?: number | null }) {
    this.#current = {
      trackId: track.id,
      duration: track.duration,
      playedAt: new Date(),
      listened: 0,
      lastTime: 0,
      recorded: false,
    };
  }

  stop() {
    this.#current = undefined;
  }

  // Only counts time that was actually played, seeking is not listening.
  progress(currentTime: number, isPlaying: boolean, audioDuration: number) {
    const current = this.#current;
    if (!current || current.recorded) return;

    const delta = currentTime - current.lastTime;
    current.lastTime = currentTime;
    if (isPlaying && delta > 0 && delta < 5) current.listened += delta;

    const duration = current.duration || audioDuration;
    if (!duration || duration <= 30) return;

    if (current.listened >= Math.min(duration / 2, 240)) {
      current.recorded = true;
      this.#record(current);
    }
  }

  #record(current: CurrentPlay) {
    if (!this.enabled) return;

    this.#savePending([
      ...this.#pending(),
      {
        id: uuid(),
        trackId: current.trackId,
        playedAt: current.playedAt.toISOString(),
      },
    ]);

    this.flush();
  }

  async flush() {
    if (this.#flushing) return;

    const batch = this.#pending().slice(0, MAX_BATCH_SIZE);
    if (batch.length === 0) return;

    this.#flushing = true;
    let sent = false;

    try {
      const response = await playApi.record(batch);

      // Invalid plays would never be accepted, so they are dropped as well.
      if ("ok" in response || response.error === "invalid_plays") {
        const ids = new Set(batch.map((play) => play.id));
        this.#savePending(this.#pending().filter((play) => !ids.has(play.id)));
        sent = true;
      }
    } catch {
      // Kept for the next attempt, e.g. when offline.
    } finally {
      this.#flushing = false;
    }

    // Plays recorded while sending (or more than one batch).
    if (sent) this.flush();
  }

  #pending(): Play[] {
    try {
      return JSON.parse(localStorage.getItem(QUEUE_KEY) ?? "[]");
    } catch {
      return [];
    }
  }

  #savePending(plays: Play[]) {
    if (plays.length === 0) {
      localStorage.removeItem(QUEUE_KEY);
    } else {
      localStorage.setItem(QUEUE_KEY, JSON.stringify(plays));
    }
  }
}

export const playRecorder = new PlayRecorder();
