defmodule MusicBoxWeb.HealthController do
  use MusicBoxWeb, :controller

  operation :show, false

  def show(conn, _params) do
    MusicBox.Repo.query!("SELECT 1")
    text(conn, "ok")
  end
end
