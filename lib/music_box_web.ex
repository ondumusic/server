defmodule MusicBoxWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use MusicBoxWeb, :controller
      use MusicBoxWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt sw.js)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: MusicBoxWeb.Layouts]

      use Gettext, backend: MusicBoxWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def json do
    quote do
      # Translation
      use Gettext, backend: MusicBoxWeb.Gettext

      # Routes generation with the ~p sigil
      unquote(verified_routes())

      use MusicBoxWeb.Helpers.JSON
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: MusicBoxWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: MusicBoxWeb.Endpoint,
        router: MusicBoxWeb.Router,
        statics: MusicBoxWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

defmodule MusicBoxWeb.UnauthorizedError do
  defexception message: "unauthorized", plug_status: 401
end

defmodule MusicBoxWeb.ForbiddenError do
  defexception message: "forbidden", plug_status: 403
end

defmodule MusicBoxWeb.ConflictError do
  defexception message: "conflict", plug_status: 409
end

defmodule MusicBoxWeb.NotFoundError do
  defexception message: "not_found", plug_status: 404
end
