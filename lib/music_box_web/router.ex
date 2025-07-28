defmodule MusicBoxWeb.Router do
  use MusicBoxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", MusicBoxWeb do
    pipe_through :api
  end
end
