defmodule MusicBoxWeb.Router do
  use MusicBoxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
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
