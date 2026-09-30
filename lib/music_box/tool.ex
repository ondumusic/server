defmodule MusicBox.Tool do
  @moduledoc false
  @callback exec(args :: term()) :: {:ok, term()} | :ok | {:error, term()}

  def probe(path), do: impl(:probe_tool).exec(path)
  def loudness(path, timeout), do: impl(:loudness_tool).exec(path: path, timeout: timeout)
  def transcode(args), do: impl(:transcode_tool).exec(args)
  def extract_artwork(path), do: impl(:extract_artwork_tool).exec(path)
  def resize_artwork(opts), do: impl(:resize_artwork_tool).exec(opts)

  defp impl(tool) do
    Application.get_env(:music_box, tool)
  end

  @doc """
  Custom implementation to replace `System.cmd/3`, but with a timeout that will
  also kill the process if it did not finish. We also ignore stderr unless
  `stderr_to_stdout: true` is given as its just noise generally.
  """
  @spec cmd(String.t(), [String.t()], timeout: pos_integer(), stderr_to_stdout: boolean()) ::
          {binary(), non_neg_integer()} | {:error, :timeout}
  def cmd(executable, args, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    stderr = if opts[:stderr_to_stdout], do: [:stderr_to_stdout], else: []

    port =
      Port.open({:spawn_executable, executable}, [:binary, :exit_status, args: args] ++ stderr)

    collect_output(port, [], System.monotonic_time(:millisecond) + timeout)
  end

  defp collect_output(port, output, deadline) do
    remaining = max(0, deadline - System.monotonic_time(:millisecond))

    receive do
      {^port, {:data, data}} -> collect_output(port, [output | data], deadline)
      {^port, {:exit_status, status}} -> {IO.iodata_to_binary(output), status}
    after
      remaining ->
        kill(port)
        {:error, :timeout}
    end
  end

  @doc """
  Kills the OS process of a port, closing the port only closes its pipes and
  leaves the process running.
  """
  @spec kill(port()) :: :ok
  def kill(port) do
    with {:os_pid, os_pid} <- Port.info(port, :os_pid) do
      # The kill builtin of sh, the kill executable is not always installed.
      System.cmd("sh", ["-c", "kill -KILL #{os_pid}"], stderr_to_stdout: true)
    end

    # The port closes by itself once the process exited, which can happen right
    # after killing it. No messages are received once closed, so flush the ones
    # that were already received.
    try do
      Port.close(port)
    rescue
      ArgumentError -> :ok
    end

    flush(port)
  end

  defp flush(port) do
    receive do
      {^port, _message} -> flush(port)
    after
      0 -> :ok
    end
  end
end
