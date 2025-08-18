defmodule MusicBoxWeb.Router do
  use MusicBoxWeb, :router

  import MusicBoxWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_root_layout, html: {MusicBoxWeb.Layouts, :root}
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_current_user
  end

  scope "/", MusicBoxWeb do
    pipe_through :browser

    get "/", PageController, :react
    get "/login", PageController, :react
    get "/library", PageController, :react
    get "/artists", PageController, :react
    get "/artists/:id", PageController, :react

    get "/stream/:track_id", StreamController, :stream
  end

  scope "/api", MusicBoxWeb do
    pipe_through [:api]

    post "/auth/login", AuthController, :login
    delete "/auth/session", AuthController, :logout
  end

  scope "/api", MusicBoxWeb do
    pipe_through [:api, :require_authenticated_user]

    get "/artists", LibraryController, :artists
    get "/artists/:artist_id", LibraryController, :artist
    get "/artists/:artist_id/albums", LibraryController, :artist_albums
    get "/artists/:artist_id/albums/:album_id", LibraryController, :artist_album

    get "/albums", LibraryController, :albums
    get "/albums/:album_id", LibraryController, :album
  end
end
