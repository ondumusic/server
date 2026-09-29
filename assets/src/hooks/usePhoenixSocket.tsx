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
export type OnScanCallback = () => void;

export interface PhoenixSocketContext {
  waitForUpdate(callback: OnInitialDataCallback): void;
  waitForScan(callback: OnScanCallback): void;
}

const PhoenixSocketContext = createContext<PhoenixSocketContext>({
  waitForUpdate: (_callback: OnInitialDataCallback) => {},
  waitForScan: (_callback: OnScanCallback) => {},
});

export function usePhoenixSocket() {
  return useContext(PhoenixSocketContext);
}

export const PhoenixSocketProvider = ({ children }: PropsWithChildren) => {
  const { isLoggedIn } = useAuth();
  const dataCallback = useRef<OnInitialDataCallback>(null);
  const scanCallback = useRef<OnScanCallback>(null);
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
      // A function so reconnects use the current session token, e.g. after
      // changing the password. The types are outdated, it can be a function.
      authToken: (() => auth.sessionToken ?? "") as unknown as string,
    });
    socketRef.current.connect();

    // Join the channel to receive all library updates
    const channel = socketRef.current.channel("library:sync", {});
    channel.join();
    channel.on("deleted", (data) => {
      sync.pushChanges({
        deletions: data.deletions ?? [],
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
        playlistItems: data.playlistItems,
      });
    });
    channel.on("completed", (_data) => {
      if (!scanCallback.current) return;
      scanCallback.current();
      scanCallback.current = null;
    });
  }, [isLoggedIn]);

  const value = {
    waitForUpdate(callback: OnInitialDataCallback) {
      dataCallback.current = callback;
    },
    waitForScan(callback: OnScanCallback) {
      scanCallback.current = callback;
    },
  };

  return (
    <PhoenixSocketContext.Provider value={value}>
      {children}
    </PhoenixSocketContext.Provider>
  );
};
