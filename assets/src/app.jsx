import "./app.css";

import { StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import {
  createBrowserRouter,
  Link,
  RouterProvider,
  redirect,
} from "react-router";

import { Layout } from "./layout";
import { ArtistsPage } from "./pages/artists";

const router = createBrowserRouter([
  {
    id: "root",
    path: "/",
    Component: Layout,
    // ErrorBoundary: ErrorBoundary,
    HydrateFallback: () => null,
    children: [
      {
        index: true,
        Component: ArtistsPage,
      },
      {
        path: "artist",
        children: [
          {
            index: true,
            loader: () => redirect("/"),
            Component: null,
          },
          {
            path: ":id",
            Component: () => (
              <p>
                Artist Page or{" "}
                <Link to="/" class="text-emerald-600 font-bold">
                  go back
                </Link>
              </p>
            ),
          },
        ],
      },
    ],
  },
]);

const appRoot = document.getElementById("App");
if (appRoot) {
  const root = createRoot(appRoot);

  root.render(
    <StrictMode>
      <Suspense>
        <RouterProvider router={router} />
      </Suspense>
    </StrictMode>,
  );
}
