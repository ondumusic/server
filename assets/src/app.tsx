import "./app.css";

import { QueryClientProvider } from "@tanstack/react-query";
import { StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { queryClient } from "./api";
import { Loading } from "./components/Loading";
import { AudioManagerProvider } from "./hooks/useAudioManager";
import { AuthProvider } from "./hooks/useAuth";
import { ContextMenuProvider } from "./hooks/useContextMenu";
import { DialogProvider } from "./hooks/useDialog";
import { MediaSessionProvider } from "./hooks/useMediaSession";
import { PhoenixSocketProvider } from "./hooks/usePhoenixSocket";
import { PlayerProvider } from "./hooks/usePlayer";
import { QueueProvider } from "./hooks/useQueue";
import { LibraryProvider } from "./library";
import { Router } from "./router";

import "./i18next";

const appRoot = document.getElementById("App");
if (appRoot) {
  const root = createRoot(appRoot);

  root.render(
    <StrictMode>
      <Suspense fallback={<Loading />}>
        <AuthProvider>
          <LibraryProvider>
            <QueryClientProvider client={queryClient}>
              <PhoenixSocketProvider>
                <DialogProvider>
                  <QueueProvider>
                    <AudioManagerProvider>
                      <PlayerProvider>
                        <MediaSessionProvider>
                          <ContextMenuProvider>
                            <Router />
                          </ContextMenuProvider>
                        </MediaSessionProvider>
                      </PlayerProvider>
                    </AudioManagerProvider>
                  </QueueProvider>
                </DialogProvider>
              </PhoenixSocketProvider>
            </QueryClientProvider>
          </LibraryProvider>
        </AuthProvider>
      </Suspense>
    </StrictMode>,
  );
}
