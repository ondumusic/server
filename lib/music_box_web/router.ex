defmodule MusicBoxWeb.Router do
  use MusicBoxWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {MusicBoxWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MusicBoxWeb do
    pipe_through :browser

    get "/", PageController, :react
    get "/artist/:id", PageController, :react
  end

  scope "/api", MusicBoxWeb do
    pipe_through :api

    get "/artists", LibraryController, :artists
    get "/artists/:artist_id", LibraryController, :artist
    get "/artists/:artist_id/albums", LibraryController, :artist_albums
    get "/artists/:artist_id/albums/:album_id", LibraryController, :album

    get "/albums", LibraryController, :albums
    get "/albums/:album_id", LibraryController, :album
  end

  scope "/stream", MusicBoxWeb do
    get "/:song_id", StreamController, :stream
  end
end
