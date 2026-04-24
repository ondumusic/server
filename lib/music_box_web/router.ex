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
    plug OpenApiSpex.Plug.PutApiSpec, module: MusicBoxWeb.ApiSpec
    plug Casex.CamelCaseDecoderPlug
  end

  scope "/", MusicBoxWeb do
    pipe_through [:browser, MusicBoxWeb.Plugs.WebEnabled]

    get "/", PageController, :react
    get "/login", PageController, :react
    get "/artists", PageController, :react
    get "/artists/:id", PageController, :react
    get "/artists/:id/:album_id", PageController, :react

    get "/onboarding/:step", PageController, :react
  end

  scope "/" do
    pipe_through [:api, MusicBoxWeb.Plugs.DocsEnabled]
    get "/openapi", OpenApiSpex.Plug.RenderSpec, :openapi
  end

  scope "/" do
    pipe_through [:browser, MusicBoxWeb.Plugs.DocsEnabled]
    get "/docs", MusicBoxWeb.PageController, :docs
  end

  scope "/", MusicBoxWeb do
    pipe_through [:browser, :api]

    get "/artwork/:filename", ArtworkController, :show
    get "/download/:track_id", StreamController, :download
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
    get "/settings", SettingsController, :show
    post "/settings", SettingsController, :update

    get "/artists", LibraryController, :artists
    get "/artists/:artist_id", LibraryController, :artist
    get "/artists/:artist_id/albums", LibraryController, :artist_albums
    get "/artists/:artist_id/albums/:album_id", LibraryController, :artist_album

    get "/albums", LibraryController, :albums
    get "/albums/:album_id", LibraryController, :album

    get "/tracks", LibraryController, :tracks
    get "/tracks/:track_id", LibraryController, :track
    get "/tracks/:track_id/transcode", StreamController, :transcode

    get "/playlists", PlaylistController, :playlists
    post "/playlists", PlaylistController, :create_playlist
    patch "/playlists/:playlist_id", PlaylistController, :update_playlist
    delete "/playlists/:playlist_id", PlaylistController, :delete_playlist
    get "/playlists/:playlist_id", PlaylistController, :playlist
    get "/playlists/:playlist_id/items", PlaylistController, :playlist_items
    patch "/playlists/:playlist_id/items", PlaylistController, :update_playlist_items

    get "/sync", SyncController, :sync

    get "/search", SearchController, :search
  end
end
