import { NowPlaying } from "../components/NowPlaying";

export function Player() {
  return (
    <div className="flex-shrink-0 bg-emerald-600 text-white p-3 text-sm text-center">
      <NowPlaying />
    </div>
  );
}
