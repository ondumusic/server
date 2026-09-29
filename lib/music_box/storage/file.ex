defmodule MusicBox.Storage.File do
  @moduledoc false

  @behaviour MusicBox.Storage

  alias MusicBox.Utils
  require Logger

  @impl true
  def get_uri(path) do
    "file://" <> path
  end

  @chunk_size 65_536

  @impl true
  def stream!(path, nil), do: File.stream!(path, @chunk_size)

  def stream!(path, first..last//1) do
    Stream.resource(
      fn ->
        file = File.open!(path, [:binary, :read])
        {:ok, _position} = :file.position(file, first)
        {file, last - first + 1}
      end,
      fn
        {file, 0} ->
          {:halt, {file, 0}}

        {file, remaining} ->
          case IO.binread(file, min(remaining, @chunk_size)) do
            data when is_binary(data) -> {[data], {file, remaining - byte_size(data)}}
            _eof -> {:halt, {file, 0}}
          end
      end,
      fn {file, _remaining} -> File.close(file) end
    )
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
  def validate_origin("/" <> _ = path) do
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
        # Symlinks are not followed, so if a file changed into a symlink we
        # will mark it as missing.
        status =
          case File.lstat(path) do
            {:ok, %File.Stat{type: :regular}} -> :exists
            {:ok, _symlink_or_other} -> :missing
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
      fn -> list_paths(path) end,
      fn
        [] ->
          {:halt, []}

        [current | rest] ->
          walk_path(current, rest)
      end,
      fn _ -> :ok end
    )
  end

  defp walk_path(path, rest) do
    # lstat does not follow symlinks which is good, because we dont want to.
    # it will either result in duplicates or in links to files outside of the
    # music path so there is no benefit to supporting them.
    case File.lstat(path, time: :posix) do
      {:ok, %File.Stat{type: :regular} = stat} ->
        if walk_file?(path), do: {[file_entry(path, stat)], rest}, else: {[], rest}

      {:ok, %File.Stat{type: :directory}} ->
        {[], list_paths(path) ++ rest}

      _symlink_or_error ->
        {[], rest}
    end
  end

  defp list_paths(path) do
    case File.ls(path) do
      {:ok, entries} ->
        entries
        |> Enum.sort()
        |> Enum.map(&Path.join(path, &1))

      {:error, reason} ->
        Logger.error("failed to read directory: #{path} (#{reason})")
        []
    end
  end

  defp walk_file?(path), do: Utils.valid_extname?(path) or Utils.cover_file?(path)

  @impl true
  def list_dir(path) do
    case File.ls(path) do
      {:ok, names} ->
        names
        |> Enum.sort()
        |> Enum.flat_map(&maybe_file_entry(path, &1))

      {:error, _reason} ->
        []
    end
  end

  defp maybe_file_entry(path, name) do
    full_path = Path.join(path, name)

    # Symlinks are not followed.
    case File.lstat(full_path, time: :posix) do
      {:ok, %File.Stat{type: :regular} = stat} -> [file_entry(full_path, stat)]
      _other -> []
    end
  end

  defp file_entry(path, %File.Stat{size: size, mtime: mtime}) do
    %{path: path, size: size, mtime: DateTime.from_unix!(mtime)}
  end
end
