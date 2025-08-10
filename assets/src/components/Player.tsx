import { NextIcon } from "../components/icons/NextIcon";
import { PauseIcon } from "../components/icons/PauseIcon";
import { PlayIcon } from "../components/icons/PlayIcon";
import { PrevIcon } from "../components/icons/PrevIcon";
import { NowPlaying } from "../components/NowPlaying";
import { usePlayer } from "../hooks/usePlayer";

export function Player() {
  const {
    isPlaying,
    setIsPlaying,
    hasNextSong,
    hasPrevSong,
    prevSong,
    nextSong,
  } = usePlayer();

  return (
    <div className="flex-shrink-0 bg-emerald-600 text-white p-3 text-sm text-center">
      <div className="flex justify-center items-center w-full">
        <button
          type="button"
          disabled={!hasPrevSong}
          className="disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md"
          onClick={() => prevSong()}
        >
          <PrevIcon className="size-6" />
        </button>
        <button
          type="button"
          className="disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md"
          onClick={() => setIsPlaying(!isPlaying)}
        >
          {isPlaying ? (
            <PauseIcon className="size-8" />
          ) : (
            <PlayIcon className="size-8" />
          )}
        </button>
        <button
          type="button"
          disabled={!hasNextSong}
          className="disabled:opacity-20 hover:bg-white/10 active:opacity-80 p-2 rounded-md"
          onClick={() => nextSong()}
        >
          <NextIcon className="size-6" />
        </button>

        <div className="w-8"></div>
        <NowPlaying />
      </div>
    </div>
  );
}
