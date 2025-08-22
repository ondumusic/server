import { createBrowserRouter, redirect } from "react-router";
import { RootErrorBoundary } from "./components/RootErrorBoundary";
import { ArtistsLayout } from "./layouts/ArtistsLayout";
import { PrivateRootLayout } from "./layouts/PrivateRootLayout";
import { RootLayout } from "./layouts/RootLayout";
import { ArtistAlbumListView } from "./views/ArtistAlbumListView";
import { LoginView } from "./views/LoginView";

export const router = createBrowserRouter([
  {
    id: "public",
    path: "/",
    Component: RootLayout,
    ErrorBoundary: RootErrorBoundary,
    HydrateFallback: () => null,
    children: [
      {
        path: "/login",
        Component: LoginView,
      },
    ],
  },
  {
    id: "private",
    path: "/",
    Component: PrivateRootLayout,
    ErrorBoundary: RootErrorBoundary,
    HydrateFallback: () => null,
    children: [
      {
        path: "/",
        Component: ArtistsLayout,
        children: [
          {
            index: true,
            Component: () => <ArtistAlbumListView />,
          },
          {
            path: "artists",
            children: [
              {
                index: true,
                loader: () => redirect("/"),
              },
              {
                path: ":artistId",
                Component: () => <ArtistAlbumListView />,
              },
            ],
          },
        ],
      },
    ],
  },
]);
