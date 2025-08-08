import { usePlayer } from "../hooks/usePlayer";

export function Player() {
  const { currentSong } = usePlayer();

  return (
    <div className="flex-shrink-0 bg-emerald-600 text-white p-3 text-xs text-center shadow-[0px_-7px_22px_-8px_rgba(0,_0,_0,_0.1)]">
      <div className="bg-emerald-800/40 py-2 px-8 rounded-lg max-w-xl mx-auto">
        <h4 className="whitespace-nowrap text-ellipsis overflow-hidden font-semibold">
          {currentSong.name}
        </h4>
        <h5 className="whitespace-nowrap text-ellipsis overflow-hidden text-white/70">
          The Artist - The Album
        </h5>
      </div>
    </div>
  );
}
