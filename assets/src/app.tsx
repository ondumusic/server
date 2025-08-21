import "./app.css";

import { QueryClientProvider } from "@tanstack/react-query";
import { StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { RouterProvider } from "react-router";
import { Loading } from "./components/Loading";
import { AudioManagerProvider } from "./hooks/useAudioManager";
import { AuthProvider } from "./hooks/useAuth";
import { MediaSessionProvider } from "./hooks/useMediaSession";
import { PhoenixSocketProvider } from "./hooks/usePhoenixSocket";
import { PlayerProvider } from "./hooks/usePlayer";
import { QueueProvider } from "./hooks/useQueue";
import { router } from "./router";
import { queryClient } from "./utils/queryClient";
import "./i18next";

const appRoot = document.getElementById("App");
if (appRoot) {
  const root = createRoot(appRoot);

  root.render(
    <StrictMode>
      <Suspense fallback={<Loading />}>
        <AuthProvider>
          <PhoenixSocketProvider>
            <QueueProvider>
              <AudioManagerProvider>
                <PlayerProvider>
                  <MediaSessionProvider>
                    <QueryClientProvider client={queryClient}>
                      <RouterProvider router={router} />
                    </QueryClientProvider>
                  </MediaSessionProvider>
                </PlayerProvider>
              </AudioManagerProvider>
            </QueueProvider>
          </PhoenixSocketProvider>
        </AuthProvider>
      </Suspense>
    </StrictMode>,
  );
}
