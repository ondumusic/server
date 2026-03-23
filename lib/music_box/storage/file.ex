defmodule MusicBox.Storage.File do
  @moduledoc false

  @behaviour MusicBox.Storage

  alias MusicBox.Utils
  require Logger

  @impl true
  def get_uri("/" <> _ = path) do
    "file://" <> path
  end

  @impl true
  def stream!(path) do
    File.stream!(path, 4096)
  end

  @impl true
  def get_bytes(path, start_byte, bytes_to_read) do
    case File.open(path, [:binary, :read]) do
      {:ok, file} ->
        :file.position(file, start_byte)
        chunk_data = IO.binread(file, bytes_to_read)
        File.close(file)
        chunk_data

      _ ->
        nil
    end
  end

  @impl true
  def validate_origin(path) do
    with true <- File.dir?(path),
         {:ok, _} <- File.ls(path) do
      :ok
    else
      false -> {:error, :enotdir}
      {:error, :eacces} -> {:error, :eacces}
      {:error, :enoent} -> {:error, :enoent}
    end
  end

  @impl true
  def find_missing_files(paths) do
    paths
    |> Task.async_stream(
      fn path ->
        status =
          case File.stat(path) do
            {:ok, _stat} -> :exists
            {:error, :enoent} -> :missing
            {:error, reason} -> {:error, reason}
          end

        {path, status}
      end,
      max_concurrency: 3,
      timeout: 5_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, {path, :missing}} ->
        [path]

      {:ok, {path, {:error, reason}}} ->
        Logger.warning("failed to verify #{path} (#{reason})")
        []

      {:ok, {_path, :exists}} ->
        []

      {:exit, :timeout} ->
        Logger.warning("timeout while checking if files still exist")
        []
    end)
  end

  @impl true
  def walk(path) do
    Stream.resource(
      fn -> [path] end,
      fn
        [] ->
          {:halt, []}

        [current | rest] ->
          cond do
            File.regular?(current) and Utils.valid_extname?(current) -> {[current], rest}
            File.dir?(current) -> walk_dir(current, rest)
            true -> {[], rest}
          end
      end,
      fn _ -> :ok end
    )
    |> Stream.map(fn path ->
      %File.Stat{size: size, mtime: mtime} = File.stat!(path, time: :posix)

      checksum =
        path
        |> File.stream!()
        |> Enum.reduce(:crypto.hash_init(:sha), &:crypto.hash_update(&2, &1))
        |> :crypto.hash_final()
        |> Base.encode16(case: :lower)

      %{
        path: path,
        size: size,
        mtime: DateTime.from_unix!(mtime),
        checksum: checksum
      }
    end)
  end

  defp walk_dir(path, rest) do
    case File.ls(path) do
      {:ok, []} ->
        {[], rest}

      {:ok, entries} ->
        new_paths =
          entries
          |> Enum.sort()
          |> Enum.map(&Path.join(path, &1))

        {[], new_paths ++ rest}

      {:error, reason} ->
        Logger.error("failed to read directory: #{path} (#{reason})")
        {[], rest}
    end
  end
end
