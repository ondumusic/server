import { createBrowserRouter, redirect } from "react-router";
import { ArtistsLayout } from "./layouts/artists_layout";
import { RootLayout } from "./layouts/root_layout";
import { ArtistAlbumList } from "./views/artist_album_list";
import { EmptyView } from "./views/empty";

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
            Component: () => <EmptyView message="No Results" />,
          },
          {
            path: "artist",
            children: [
              {
                index: true,
                loader: () => redirect("/"),
              },
              {
                path: ":artistId",
                Component: () => <ArtistAlbumList />,
              },
            ],
          },
        ],
      },
    ],
  },
]);
