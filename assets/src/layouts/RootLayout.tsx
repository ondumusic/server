import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { usePlayer } from "../hooks/usePlayer";

export function RootLayout() {
  const { isVisible } = usePlayer();

  return (
    <div className="flex flex-col h-full">
      <Outlet />
      {isVisible ? <Player /> : null}
    </div>
  );
}
