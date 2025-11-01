defmodule MusicBox.FileScanner.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    Supervisor.init(
      [
        MusicBox.FileScanner.Agent,
        MusicBox.FileScanner.PeriodicWorker
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
