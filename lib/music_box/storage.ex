defmodule MusicBox.Storage do
  @moduledoc false

  @doc """
  Returns uri to the file, either https:// or file:// scheme ideally.
  Should be compatible as input for ffmpeg/ffprobe.
  """
  @callback get_uri(path :: String.t()) :: String.t()
  @spec get_uri(path :: String.t()) :: String.t()
  def get_uri(path), do: impl().get_uri(path)

  @doc """
  Validates the existence of the origin directory.
  """
  @type validate_origin_result :: :ok | {:error, :eacces} | {:error, :enoent} | {:error, :enotdir}
  @callback validate_origin(path :: String.t()) :: validate_origin_result()
  @spec validate_origin(path :: String.t()) :: validate_origin_result()
  def validate_origin(path), do: impl().validate_origin(path)

  @doc """
  Finds all music file paths inside the given path.
  """
  @type file_entry :: %{
          path: String.t(),
          size: non_neg_integer(),
          mtime: DateTime.t()
        }
  @callback walk(path :: String.t()) :: Enumerable.t(file_entry())
  @spec walk(path :: String.t()) :: Enumerable.t(file_entry())
  def walk(path), do: impl().walk(path)

  @doc """
  Filters the given list of paths and returns only the paths of files that are
  no longer found in storage.
  """
  @callback find_missing_files(paths :: [String.t()]) :: [String.t()]
  @spec find_missing_files(paths :: [String.t()]) :: [String.t()]
  def find_missing_files(paths), do: impl().find_missing_files(paths)

  @doc """
  Returns a streaming Enumerable for the given path.
  """
  @callback stream!(path :: String.t()) :: Enumerable.t()
  @spec stream!(path :: String.t()) :: Enumerable.t()
  def stream!(path), do: impl().stream!(path)

  @doc """
  Returns specific range of bytes from a file.
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
  def get_bytes(path, start_byte, bytes_to_read),
    do: impl().get_bytes(path, start_byte, bytes_to_read)

  defp impl, do: Application.get_env(:music_box, :storage_impl)
end
