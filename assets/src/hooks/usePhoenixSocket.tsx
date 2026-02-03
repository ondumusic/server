import { Socket } from "phoenix";
import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useRef,
} from "react";
import { useAuth } from "../hooks/useAuth";
import { auth } from "../services/auth";
import type { Album } from "../types";
import { updateCache } from "../utils/updateCache";

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
    const channel = socketRef.current.channel("library:updated", {});
    channel.join();
    channel.on("processed", (data) => {
      if (dataCallback.current) {
        (dataCallback.current as OnInitialDataCallback)();
        dataCallback.current = null;
      }

      // For artists we can look at all cached queries
      if (data.artists) {
        for (const artist of data.artists) {
          updateCache({ queryKey: ["artist", artist.id] }, [artist]);

          updateCache({ queryKey: ["artists"], exact: true }, [artist]);
        }
      }

      // For albums we want to make sure they are updated for the correct artist
      if (data.albums) {
        const groupedAlbums = Object.groupBy(
          data.albums,
          (album: Album) => album.artistId,
        );

        for (const artistId in groupedAlbums) {
          if (!artistId) continue;

          updateCache(
            { queryKey: ["albums", artistId], exact: true },
            groupedAlbums[artistId] as Album[],
          );
        }
      }
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
