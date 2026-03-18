defmodule MusicBoxWeb.Plugs.WebEnabled do
  @moduledoc false

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:music_box, :web_enabled) do
      conn
    else
      raise MusicBoxWeb.NotFoundError
    end
  end
end
