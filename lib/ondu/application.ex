defmodule Ondu.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OnduWeb.Telemetry,
      Ondu.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:ondu, :ecto_repos), skip: skip_migrations?()},
      {Phoenix.PubSub, name: Ondu.PubSub},
      OnduWeb.LoginLimiter,
      # Start to serve requests, typically the last entry
      OnduWeb.Endpoint
    ]

    children =
      if Ondu.env() == :test,
        do: children,
        else:
          children ++
            [
              Ondu.FileScanner.Supervisor,
              Ondu.Transcoder,
              Ondu.Artwork.Worker,
              Ondu.Loudness.Worker,
              Ondu.Cleanup.Worker
            ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ondu.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OnduWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil or
      System.get_env("SKIP_MIGRATIONS") == "true"
  end
end
