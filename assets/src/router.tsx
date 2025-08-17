import { createBrowserRouter, redirect } from "react-router";
import { RootErrorBoundary } from "./components/RootErrorBoundary";
import i18next from "./i18next";
import { ArtistsLayout } from "./layouts/ArtistsLayout";
import { PrivateRootLayout } from "./layouts/PrivateRootLayout";
import { RootLayout } from "./layouts/RootLayout";
import { ArtistAlbumListView } from "./views/ArtistAlbumListView";
import { EmptyView } from "./views/EmptyView";
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
            Component: () => (
              <EmptyView
                message={i18next.t("emptyView.noResults", {
                  defaultValue: "No Results",
                })}
              />
            ),
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
