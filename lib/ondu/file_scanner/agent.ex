defmodule Ondu.FileScanner.Agent do
  @moduledoc false
  use Agent

  defstruct [:started_at, :completed_at, :duration, :scan_type, running?: false]

  def start_link(_opts) do
    Agent.start_link(fn -> %__MODULE__{} end, name: __MODULE__)
  end

  def running? do
    get_state().running?
  end

  def start(scan_type) do
    set_state(%{
      started_at: now(),
      completed_at: nil,
      duration: nil,
      scan_type: scan_type,
      running?: true
    })
  end

  def stop do
    state = get_state()

    if state.started_at do
      completed_at = now()
      duration = completed_at - state.started_at

      set_state(%{
        completed_at: completed_at,
        duration: duration,
        running?: false
      })
    end
  end

  def get_state do
    Agent.get(__MODULE__, & &1)
  end

  defp set_state(params) do
    Agent.update(__MODULE__, &Map.merge(&1, params))
  end

  defp now, do: System.monotonic_time(:millisecond)
end
