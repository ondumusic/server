import type { ChangeEvent } from "react";
import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { usePlayer } from "../hooks/usePlayer";

export function RootLayout() {
  const {
    audioRef,
    isVisible,
    currentSong,
    nextSong,
    setDuration,
    setCurrentTime,
  } = usePlayer();

  const onTimeUpdate = (event: ChangeEvent<HTMLAudioElement>) => {
    setCurrentTime(event.target.currentTime);
  };

  const onLoadedMetadata = (event: ChangeEvent<HTMLAudioElement>) => {
    setDuration(event.target.duration);
  };

  return (
    <>
      <div className="flex flex-col max-h-screen">
        <Outlet />
        {isVisible ? <Player /> : null}
      </div>
      <audio
        ref={audioRef}
        src={currentSong && `/stream/${currentSong.id}`}
        onTimeUpdate={onTimeUpdate}
        onLoadedMetadata={onLoadedMetadata}
        onEnded={nextSong}
        className="hidden"
      />
    </>
  );
}
