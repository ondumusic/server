import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { usePlayer } from "../hooks/usePlayer";

export function RootLayout() {
  const { isPlaying } = usePlayer();

  return (
    <div className="flex flex-col max-h-screen">
      <Outlet />
      {isPlaying ? <Player /> : null}
    </div>
  );
}
