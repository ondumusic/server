import "./app.css";

import { StrictMode, Suspense, useEffect } from "react";
import { createRoot } from "react-dom/client";
import { RouterProvider } from "react-router";
import { createBrowserRouter, redirect, Link } from "react-router";

import { Layout } from "./layout";

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
        Component: () => <div class="w-screen h-screen flex items-center justify-center">
          <p class="max-w-md mx-4">
            Hello <span class="font-bold">React</span>!
            <Link to="/artist/the-beatles">The Beatles</Link>
          </p>
        </div>,
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
            Component: () => <p>Artist Page or <Link to="/" class="text-emerald-600 font-bold">go back</Link></p>,
          },
        ]
      }
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
