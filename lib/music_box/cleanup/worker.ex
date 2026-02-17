defmodule MusicBox.Cleanup.Worker do
  @moduledoc false

  use GenServer

  alias MusicBox.Cleanup

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    default_state = []
    Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:updated")
    {:ok, default_state}
  end

  @impl true
  def handle_info(%{topic: "library:updated", payload: _payload}, state) do
    Cleanup.work([:unused])
    {:noreply, state}
  end
end
