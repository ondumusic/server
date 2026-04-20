defmodule MusicBox.Storage do
  @moduledoc false

  @doc """
  Returns uri to the file, either https:// or file:// scheme ideally.
  Should be compatible as input for ffmpeg/ffprobe.
  Path should be relative to Settings.music_path.
  """
  @callback get_uri(path :: String.t()) :: String.t()
  @spec get_uri(path :: String.t()) :: String.t()
  def get_uri(path) do
    impl().get_uri(absolute(path))
  end

  @doc """
  Validates the existence of the origin directory.
  Path should be absolute.
  """
  @type validate_origin_result :: :ok | {:error, :eacces} | {:error, :enoent} | {:error, :enotdir}
  @callback validate_origin(path :: String.t()) :: validate_origin_result()
  @spec validate_origin(path :: String.t()) :: validate_origin_result()
  def validate_origin("/" <> _ = path) do
    impl().validate_origin(path)
  end

  @doc """
  Finds all music file paths inside the given path.
  Path should be relative to Settings.music_path.
  """
  @type file_entry :: %{
          path: String.t(),
          size: non_neg_integer(),
          mtime: DateTime.t()
        }
  @callback walk(path :: String.t()) :: Enumerable.t(file_entry())
  @spec walk(path :: String.t()) :: Enumerable.t(file_entry())
  def walk(path) do
    impl().walk(absolute(path))
    |> Stream.map(&strip_prefix/1)
  end

  @doc """
  Filters the given list of paths and returns only the paths of files that are
  no longer found in storage.
  Paths should be relative to Settings.music_path.
  """
  @callback find_missing_files(paths :: [String.t()]) :: Enumerable.t(String.t())
  @spec find_missing_files(paths :: [String.t()]) :: Enumerable.t(String.t())
  def find_missing_files(paths) do
    abs_paths = Enum.map(paths, &absolute/1)

    impl().find_missing_files(abs_paths)
    |> Stream.map(&strip_prefix/1)
  end

  @doc """
  Returns a streaming Enumerable for the given path.
  Path should be relative to Settings.music_path.
  """
  @callback stream!(path :: String.t()) :: Enumerable.t()
  @spec stream!(path :: String.t()) :: Enumerable.t()
  def stream!(path) do
    impl().stream!(absolute(path))
  end

  @doc """
  Returns specific range of bytes from a file.
  Path should be relative to Settings.music_path.
  """
  @callback get_bytes(
              path :: String.t(),
              start_byte :: non_neg_integer(),
              bytes_to_read :: non_neg_integer()
            ) :: iodata()
  @spec get_bytes(
          path :: String.t(),
          start_byte :: non_neg_integer(),
          bytes_to_read :: non_neg_integer()
        ) :: iodata()
  def get_bytes(path, start_byte, bytes_to_read) do
    impl().get_bytes(absolute(path), start_byte, bytes_to_read)
  end

  defp impl, do: Application.get_env(:music_box, :storage_impl)

  defp strip_prefix("" <> path) do
    # Storage might return paths without leading / (looking at you S3)
    # but to use relative_to we would like absolute paths here.
    path = if String.starts_with?(path, "/"), do: path, else: "/" <> path

    # NOTE: settings is stored in a `:persistent_term` so this should not be N+1
    settings = MusicBox.Settings.get()
    Path.relative_to(path, settings.music_path || "/", force: true)
  end

  defp strip_prefix(%{path: path} = entry) do
    %{entry | path: strip_prefix(path)}
  end

  # NOTE: If we do get an absolute path, we don't have to prefix it.
  # this should not really happen though, except for some known hacky tests
  # with the iTunSMPB writing.
  defp absolute("/" <> _ = path) when path != "/", do: path

  defp absolute(path) do
    # NOTE: settings is stored in a `:persistent_term` so this should not be N+1
    settings = MusicBox.Settings.get()
    Path.join(settings.music_path || "/", path)
  end
end
