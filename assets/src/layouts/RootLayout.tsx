import type { ChangeEvent } from "react";
import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { usePlayer } from "../hooks/usePlayer";

export function RootLayout() {
  const {
    audioRef,
    isVisible,
    currentTrack,
    nextTrack,
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
      <div className="flex flex-col h-full">
        <Outlet />
        {isVisible ? <Player /> : null}
      </div>
      <audio
        ref={audioRef}
        src={currentTrack && `/stream/${currentTrack.id}`}
        onTimeUpdate={onTimeUpdate}
        onLoadedMetadata={onLoadedMetadata}
        onEnded={nextTrack}
        className="hidden"
      />
    </>
  );
}
