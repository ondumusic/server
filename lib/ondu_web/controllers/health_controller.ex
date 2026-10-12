defmodule OnduWeb.HealthController do
  use OnduWeb, :controller

  operation :show, false

  def show(conn, _params) do
    Ondu.Repo.query!("SELECT 1")
    text(conn, "ok")
  end
end
