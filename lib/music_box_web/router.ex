defmodule MusicBoxWeb.Router do
  @moduledoc false

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
    get "/artists/:id/:album_id", PageController, :react

    get "/onboarding/:step", PageController, :react

    get "/artwork/:filename", ArtworkController, :show
    get "/stream/:track_id", StreamController, :stream
  end

  scope "/api", MusicBoxWeb do
    pipe_through [:api]

    post "/auth/login", AuthController, :login
    post "/auth/signup", AuthController, :signup
    delete "/auth/session", AuthController, :logout
  end

  scope "/api", MusicBoxWeb do
    pipe_through [:api, :require_authenticated_user]

    get "/auth/me", AuthController, :current_user
    get "/auth/playtoken", AuthController, :play_token
    post "/settings", SettingsController, :update

    get "/artists", LibraryController, :artists
    get "/artists/:artist_id", LibraryController, :artist
    get "/artists/:artist_id/albums", LibraryController, :artist_albums
    get "/artists/:artist_id/albums/:album_id", LibraryController, :artist_album

    get "/albums", LibraryController, :albums
    get "/albums/:album_id", LibraryController, :album

    get "/tracks", LibraryController, :tracks
    get "/tracks/:track_id", LibraryController, :track

    post "/transcode/:track_id", StreamController, :transcode

    get "/search", SearchController, :search
  end
end
