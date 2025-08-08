import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { usePlayer } from "../hooks/usePlayer";

export function RootLayout() {
  const { audioRef, isPlaying, currentSong } = usePlayer();

  const onTimeUpdate = (a) => console.log(a.timeStamp);
  const onLoadedMetadata = (a) => console.log(a);

  return (
    <div className="flex flex-col max-h-screen">
      <audio
        ref={audioRef}
        src={currentSong && `/stream/${currentSong.id}`}
        onTimeUpdate={onTimeUpdate}
        onLoadedMetadata={onLoadedMetadata}
        class="hidden"
        playsinline
      />
      <Outlet />
      {isPlaying ? <Player /> : null}
    </div>
  );
}
