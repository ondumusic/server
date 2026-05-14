import "./app.css";

import { StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { Loading } from "./components/Loading";
import { AudioManagerProvider } from "./hooks/useAudioManager";
import { AuthProvider } from "./hooks/useAuth";
import { ContextMenuProvider } from "./hooks/useContextMenu";
import { DialogProvider } from "./hooks/useDialog";
import { MediaSessionProvider } from "./hooks/useMediaSession";
import { PhoenixSocketProvider } from "./hooks/usePhoenixSocket";
import { PlayerProvider } from "./hooks/usePlayer";
import { QueueProvider } from "./hooks/useQueue";
import { ThemeProvider } from "./hooks/useTheme";
import { LibraryProvider } from "./library";
import { Router } from "./router";
import { applyAccentColor } from "./utils/updateAccentColor";

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register("/sw.js")
      .catch((err) => console.error("SW registration failed:", err));
  });
}

import "./i18next";

const appRoot = document.getElementById("App");
if (appRoot) {
  applyAccentColor();

  const root = createRoot(appRoot);
  root.render(
    <StrictMode>
      <Suspense fallback={<Loading />}>
        <ThemeProvider>
          <AuthProvider>
            <LibraryProvider>
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
            </LibraryProvider>
          </AuthProvider>
        </ThemeProvider>
      </Suspense>
    </StrictMode>,
  );
}
