defmodule OnduWeb.LoginLimiter do
  @moduledoc """
  This module limits failed login attempts in an attempt to at the very least
  slow down brute force attacks.

  The limit applies to all login attempts rather than per ip address, as the
  client ip will depend on the reverse proxy setup, which could be different for
  every deployment. This means that while someone is guessing logging in on a
  new device has to wait as well.

  Existing sessions and play tokens are not affected.

  Failures are kept in memory, a restart clears them.
  """

  use GenServer

  @max_failures 10
  @period_ms :timer.minutes(15)

  @type opts :: [name: GenServer.name(), max_failures: pos_integer(), period_ms: pos_integer()]

  @spec start_link(opts()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Returns `:ok` when logging in is allowed, or the number of seconds after
  which it is allowed again.
  """
  @spec check(GenServer.server()) :: :ok | {:error, retry_after :: pos_integer()}
  def check(server \\ __MODULE__), do: GenServer.call(server, :check)

  @spec failed(GenServer.server()) :: :ok
  def failed(server \\ __MODULE__), do: GenServer.call(server, :failed)

  @spec succeeded(GenServer.server()) :: :ok
  def succeeded(server \\ __MODULE__), do: GenServer.call(server, :succeeded)

  @impl true
  def init(opts) do
    {:ok,
     %{
       max_failures: Keyword.get(opts, :max_failures, @max_failures),
       period_ms: Keyword.get(opts, :period_ms, @period_ms),
       # Newest first
       failures: []
     }}
  end

  @impl true
  def handle_call(:check, _from, state) do
    state = prune(state)

    if length(state.failures) < state.max_failures do
      {:reply, :ok, state}
    else
      oldest = List.last(state.failures)
      retry_after_ms = oldest + state.period_ms - now()
      {:reply, {:error, max(1, ceil(retry_after_ms / 1000))}, state}
    end
  end

  def handle_call(:failed, _from, state) do
    state = prune(state)
    {:reply, :ok, %{state | failures: Enum.take([now() | state.failures], state.max_failures)}}
  end

  def handle_call(:succeeded, _from, state) do
    {:reply, :ok, %{state | failures: []}}
  end

  defp prune(state) do
    cutoff = now() - state.period_ms
    %{state | failures: Enum.take_while(state.failures, &(&1 > cutoff))}
  end

  defp now, do: System.monotonic_time(:millisecond)
end
