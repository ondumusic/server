import type { ReactNode } from "react";
import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { usePlayer } from "../hooks/usePlayer";

interface Props {
  children?: ReactNode;
}

export function RootLayout({ children }: Props) {
  const { isVisible } = usePlayer();

  return (
    <div className="flex flex-col h-full">
      {children ? children : <Outlet />}
      {isVisible ? <Player /> : null}
    </div>
  );
}
