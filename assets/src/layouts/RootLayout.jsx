import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { usePlayer } from "../hooks/usePlayer";

export function RootLayout() {
  const {
    audioRef,
    isPlaying,
    currentSong,
    setDuration,
    setCurrentTime,
    setPercentage,
  } = usePlayer();

  const onTimeUpdate = ({ target: { currentTime, duration } }) => {
    const percentage = (currentTime / duration) * 100;
    setCurrentTime(currentTime);
    setPercentage(percentage);
  };

  const onLoadedMetadata = () => {
    setDuration(audioRef.current.duration);
  };

  return (
    <>
      <div className="flex flex-col max-h-screen">
        <Outlet />
        {isPlaying ? <Player /> : null}
      </div>
      <audio
        ref={audioRef}
        src={currentSong && `/stream/${currentSong.id}`}
        onTimeUpdate={onTimeUpdate}
        onLoadedMetadata={onLoadedMetadata}
        class="hidden"
        playsinline
      />
    </>
  );
}
