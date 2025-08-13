import "./app.css";

import { QueryClientProvider } from "@tanstack/react-query";
import { StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { RouterProvider } from "react-router";
import { AudioManagerProvider } from "./hooks/useAudioManager";
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
      <Suspense>
        <QueueProvider>
          <AudioManagerProvider>
            <PlayerProvider>
              <QueryClientProvider client={queryClient}>
                <RouterProvider router={router} />
              </QueryClientProvider>
            </PlayerProvider>
          </AudioManagerProvider>
        </QueueProvider>
      </Suspense>
    </StrictMode>,
  );
}
