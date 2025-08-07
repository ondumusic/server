import { usePlayer } from "../hooks/usePlayer";

export function Player() {
  const { currentSong } = usePlayer();

  return (
    <div className="flex-shrink-0 bg-emerald-600 text-white p-3 text-sm text-center shadow-[0px_-7px_22px_-8px_rgba(0,_0,_0,_0.1)]">
      <strong>Now Playing:</strong>
      {currentSong.name}
    </div>
  );
}
