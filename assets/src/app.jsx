import "./app.css";

import { QueryClientProvider } from "@tanstack/react-query";
import { StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { RouterProvider } from "react-router";

import { router } from "./router";
import { queryClient } from "./utils/query_client";

const appRoot = document.getElementById("App");
if (appRoot) {
  const root = createRoot(appRoot);

  root.render(
    <StrictMode>
      <Suspense>
        <QueryClientProvider client={queryClient}>
          <RouterProvider router={router} />
        </QueryClientProvider>
      </Suspense>
    </StrictMode>,
  );
}
