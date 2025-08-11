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
    get "/library", PageController, :react
    get "/artists", PageController, :react
    get "/artists/:id", PageController, :react

    get "/stream/:track_id", StreamController, :stream
  end

  scope "/api", MusicBoxWeb do
    pipe_through :api

    get "/artists", LibraryController, :artists
    get "/artists/:artist_id", LibraryController, :artist
    get "/artists/:artist_id/albums", LibraryController, :artist_albums
    get "/artists/:artist_id/albums/:album_id", LibraryController, :artist_album

    get "/albums", LibraryController, :albums
    get "/albums/:album_id", LibraryController, :album
  end
end
