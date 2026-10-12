defmodule OnduWeb.Plugs.DocsEnabled do
  @moduledoc false

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:ondu, :docs_enabled) do
      conn
    else
      raise OnduWeb.NotFoundError
    end
  end
end
