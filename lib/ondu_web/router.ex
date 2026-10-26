defmodule OnduWeb.Router do
  @moduledoc false

  use OnduWeb, :router

  import OnduWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_root_layout, html: {OnduWeb.Layouts, :root}
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_current_user
    plug OpenApiSpex.Plug.PutApiSpec, module: OnduWeb.ApiSpec
    plug Casex.CamelCaseDecoderPlug
  end

  scope "/", OnduWeb do
    pipe_through [:browser, OnduWeb.Plugs.WebEnabled]

    get "/", PageController, :react
    get "/login", PageController, :react
    get "/artists", PageController, :react
    get "/artists/:id", PageController, :react
    get "/artists/:id/:album_id", PageController, :react
    get "/albums", PageController, :react
    get "/albums/:id", PageController, :react
    get "/playlists", PageController, :react
    get "/playlists/:id", PageController, :react
    get "/settings", PageController, :react
    get "/settings/appearance", PageController, :react
    get "/settings/playback", PageController, :react
    get "/settings/storage", PageController, :react
    get "/settings/account", PageController, :react
    get "/settings/library", PageController, :react
    get "/settings/issues", PageController, :react

    get "/onboarding/:step", PageController, :react
  end

  scope "/", OnduWeb do
    get "/health", HealthController, :show
  end

  scope "/" do
    pipe_through [:api, OnduWeb.Plugs.DocsEnabled]
    get "/openapi", OpenApiSpex.Plug.RenderSpec, :openapi
  end

  scope "/" do
    pipe_through [:browser, OnduWeb.Plugs.DocsEnabled]
    get "/docs", OnduWeb.PageController, :docs
  end

  scope "/", OnduWeb do
    pipe_through [:browser, :api]

    get "/artwork/:kind/:id/:hash/:filename", ArtworkController, :show
    get "/download/:track_id", StreamController, :download
    get "/stream/:track_id", StreamController, :stream
  end

  scope "/api", OnduWeb do
    pipe_through [:api]

    post "/auth/login", AuthController, :login
    post "/auth/signup", AuthController, :signup
    delete "/auth/session", AuthController, :logout
  end

  scope "/api", OnduWeb do
    pipe_through [:api, :require_authenticated_user]

    get "/auth/me", AuthController, :current_user
    get "/info", InfoController, :info
    get "/auth/playtoken", AuthController, :play_token
    get "/settings", SettingsController, :show
    patch "/settings", SettingsController, :update

    get "/artists", LibraryController, :artists
    get "/artists/:artist_id", LibraryController, :artist
    put "/artists/:artist_id/artwork", ArtistArtworkController, :update
    delete "/artists/:artist_id/artwork", ArtistArtworkController, :delete
    get "/artists/:artist_id/albums", LibraryController, :artist_albums
    get "/artists/:artist_id/albums/:album_id", LibraryController, :artist_album

    get "/albums", LibraryController, :albums
    get "/albums/:album_id", LibraryController, :album

    get "/tracks", LibraryController, :tracks
    get "/tracks/:track_id", LibraryController, :track
    post "/plays", PlayController, :record_plays

    get "/annotations/:namespace/:entity_type", AnnotationController, :index
    put "/annotations/:namespace/:entity_type", AnnotationController, :update

    get "/playlists", PlaylistController, :playlists
    post "/playlists", PlaylistController, :create_playlist
    patch "/playlists/:playlist_id", PlaylistController, :update_playlist
    delete "/playlists/:playlist_id", PlaylistController, :delete_playlist
    get "/playlists/:playlist_id", PlaylistController, :playlist
    get "/playlists/:playlist_id/items", PlaylistController, :playlist_items
    patch "/playlists/:playlist_id/items", PlaylistController, :update_playlist_items

    patch "/user/password", UserController, :update_password

    get "/sync", SyncController, :sync
    post "/notices/:notice_id/dismiss", NoticeController, :dismiss

    post "/scan", LibraryController, :scan

    get "/search", SearchController, :search
    get "/issues", IssueController, :issues
  end
end
