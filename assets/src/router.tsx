import { createBrowserRouter, redirect } from "react-router";
import i18next from "./i18next";
import { ArtistsLayout } from "./layouts/ArtistsLayout";
import { RootLayout } from "./layouts/RootLayout";
import { ArtistAlbumListView } from "./views/ArtistAlbumListView";
import { EmptyView } from "./views/EmptyView";

export const router = createBrowserRouter([
  {
    id: "root",
    path: "/",
    Component: RootLayout,
    // ErrorBoundary: ErrorBoundary,
    HydrateFallback: () => null,
    children: [
      {
        path: "/",
        Component: ArtistsLayout,
        children: [
          {
            index: true,
            Component: () => <EmptyView message={i18next.t("noResults")} />,
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
