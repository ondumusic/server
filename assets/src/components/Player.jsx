import { NowPlaying } from "../components/NowPlaying";
import { usePlayer } from "../hooks/usePlayer";

export function Player() {
  const { hasNextSong, hasPrevSong, prevSong, nextSong } = usePlayer();

  return (
    <div className="flex-shrink-0 bg-emerald-600 text-white p-3 text-sm text-center">
      <div className="flex justify-center items-center w-full">
        <button
          type="button"
          disabled={!hasPrevSong}
          className="disabled:opacity-20 px-4 py-8"
          onClick={() => prevSong()}
        >
          Prev
        </button>
        <NowPlaying />
        <button
          type="button"
          disabled={!hasNextSong}
          className="disabled:opacity-20 px-4 py-8"
          onClick={() => nextSong()}
        >
          Next
        </button>
      </div>
    </div>
  );
}
