defmodule MusicBox.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MusicBoxWeb.Telemetry,
      MusicBox.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:music_box, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:music_box, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MusicBox.PubSub},
      MusicBoxWeb.LoginLimiter,
      # Start to serve requests, typically the last entry
      MusicBoxWeb.Endpoint
    ]

    children =
      if MusicBox.env() == :test,
        do: children,
        else:
          children ++
            [
              MusicBox.FileScanner.Supervisor,
              MusicBox.Transcoder,
              MusicBox.Artwork.Worker,
              MusicBox.Loudness.Worker,
              MusicBox.Cleanup.Worker
            ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MusicBox.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MusicBoxWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil or
      System.get_env("SKIP_MIGRATIONS") == "true"
  end
end
