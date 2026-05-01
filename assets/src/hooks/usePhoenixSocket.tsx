import { Socket } from "phoenix";
import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useRef,
} from "react";
import { useAuth } from "../hooks/useAuth";
import { sync } from "../library/sync";
import { auth } from "../services/auth";
import type { Album } from "../types";

export type OnInitialDataCallback = () => void;

export interface PhoenixSocketContext {
  waitForUpdate(callback: OnInitialDataCallback): void;
}

const PhoenixSocketContext = createContext<PhoenixSocketContext>({
  waitForUpdate: (_callback: OnInitialDataCallback) => {},
});

export function usePhoenixSocket() {
  return useContext(PhoenixSocketContext);
}

export const PhoenixSocketProvider = ({ children }: PropsWithChildren) => {
  const { isLoggedIn } = useAuth();
  const dataCallback = useRef<OnInitialDataCallback>(null);
  const socketRef = useRef<Socket>(null);

  useEffect(() => {
    if (socketRef.current && !isLoggedIn) {
      socketRef.current.disconnect();
      socketRef.current = null;
      return;
    }

    if (!isLoggedIn) return;
    if (socketRef.current) return;

    // Connect socket
    socketRef.current = new Socket("/socket", {
      params: { sessionToken: auth.sessionToken },
    });
    socketRef.current.connect();

    // Join the channel to receive all library updates
    const channel = socketRef.current.channel("library:sync", {});
    channel.join();
    channel.on("deleted", (deletions) => {
      sync.pushChanges({
        deletions,
      });
    });
    channel.on("processed", (data) => {
      if (dataCallback.current) {
        (dataCallback.current as OnInitialDataCallback)();
        dataCallback.current = null;
      }

      // Update the library
      sync.pushChanges({
        artists: data.artists,
        albums: data.albums,
        tracks: data.albums?.flatMap((album: Album) => album.tracks),
        playlists: data.playlists,
      });
    });
  }, [isLoggedIn]);

  const value = {
    waitForUpdate(callback: OnInitialDataCallback) {
      dataCallback.current = callback;
    },
  };

  return (
    <PhoenixSocketContext.Provider value={value}>
      {children}
    </PhoenixSocketContext.Provider>
  );
};
