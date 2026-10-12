defmodule Ondu.FileScanner.Analyzer do
  @moduledoc false

  alias Ondu.FileScanner.Utils
  alias Ondu.Storage
  alias Ondu.Tool

  require Logger

  defmodule Metadata do
    @moduledoc false

    defstruct [
      :artist,
      :album,
      :title,
      :track,
      :album_artist,
      :release_year,
      :compilation,
      :duration,
      :bitrate,
      :sample_rate,
      :audio_channels,
      disc: 1,
      genres: []
    ]

    @type t :: %__MODULE__{}
  end

  defmodule Result do
    @moduledoc false

    defstruct [
      :path,
      :size,
      :type,
      :last_modified_at,
      metadata: %Metadata{}
    ]

    @type t :: %__MODULE__{}
  end

  @spec analyze(file :: Storage.file_entry()) :: {:ok, Result.t()} | {:error, :analyzing_failed}
  def analyze(file) do
    with {:ok, type} <- Utils.detect_file_type(file.path),
         {:ok, metadata} <- get_metadata(file.path) do
      {:ok,
       %Result{
         path: file.path,
         size: file.size,
         type: type,
         last_modified_at: file.mtime,
         metadata: metadata
       }}
    else
      {:error, :unknown} ->
        Logger.warning(
          "Skipped #{file.path}, the file type is unsupported or the file is damaged"
        )

        {:error, :analyzing_failed}

      {:error, :probe_failed} ->
        Logger.warning("Skipped #{file.path}, ffprobe could not read it")
        {:error, :analyzing_failed}
    end
  end

  defp get_metadata(path) do
    with {:ok, json} <- Tool.probe(Storage.get_uri(path)) do
      metadata = %Metadata{}
      keys = Map.keys(metadata)

      {:ok, parse(metadata, keys, json)}
    end
  end

  defp parse(%Metadata{} = metadata, [], json) do
    # Finally we add the audio detalis
    stream =
      json
      |> Map.get("streams", [])
      |> Enum.find(&(Map.get(&1, "codec_type") == "audio"))

    bitrate =
      cond do
        value = get_field(stream, "bitrate") -> Utils.to_integer(value)
        value = get_tag(json, "BPS") -> Utils.to_integer(value)
        value = get_in(json, ["format", "bitrate"]) -> Utils.to_integer(value)
        true -> nil
      end

    %{
      metadata
      | bitrate: bitrate,
        sample_rate: stream |> get_field("sample_rate") |> Utils.to_integer(),
        audio_channels: stream |> get_field("channels") |> Utils.to_integer()
    }
  end

  @simple_fields ~w(album title)a
  defp parse(%Metadata{} = metadata, [key | keys], json) when key in @simple_fields do
    value =
      case get_tag(json, to_string(key)) do
        nil -> nil
        value -> String.trim(value)
      end

    metadata
    |> Map.put(key, value)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:album_artist = key | keys], json) do
    value =
      [
        get_tag(json, "album artist"),
        get_tag(json, "album_artist"),
        get_tag(json, "albumartist"),
        get_tag(json, "artist")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&String.trim/1)
      |> List.first()

    metadata
    |> Map.put(key, value)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:artist = key | keys], json) do
    value =
      [
        get_tag(json, "artist"),
        get_tag(json, "album artist"),
        get_tag(json, "album_artist"),
        get_tag(json, "albumartist")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&String.trim/1)
      |> List.first()

    metadata
    |> Map.put(key, value)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:disc = key | keys], json) do
    value =
      [
        get_tag(json, "disc"),
        get_tag(json, "tpa"),
        "1"
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&String.trim/1)
      |> List.first()

    current_value = Map.get(metadata, key)

    disc =
      value
      |> String.split(~r/[^0-9]/)
      |> Enum.map(&String.trim/1)
      |> List.first()
      |> Utils.to_integer()

    metadata
    |> Map.put(key, disc || current_value)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:track = key | keys], json) do
    value = get_tag(json, to_string(key)) || ""

    track =
      value
      |> String.split(~r/[^0-9]/)
      |> Enum.map(&String.trim/1)
      |> List.first()
      |> Utils.to_integer()

    metadata
    |> Map.put(key, track)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:release_year = key | keys], json) do
    value = get_tag(json, "date") || ""

    release_year =
      case Regex.scan(~r/([0-9]{4})/, value) do
        [[_, year] | _] -> Utils.to_integer(year)
        _ -> nil
      end

    metadata
    |> Map.put(key, release_year)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:compilation = key | keys], json) do
    value =
      case get_tag(json, "compilation") do
        "1" -> true
        _ -> false
      end

    metadata
    |> Map.put(key, value)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:duration = key | keys], json) do
    value = get_in(json, ["format", "duration"]) || ""

    duration =
      case Float.parse(value) do
        {duration, _rest} -> duration
        _ -> nil
      end

    metadata
    |> Map.put(key, duration)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [:genres = key | keys], json) do
    value = get_tag(json, "genre") || ""

    genre =
      value
      |> String.split(~r/[\/,;&]/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    metadata
    |> Map.put(key, genre)
    |> parse(keys, json)
  end

  defp parse(%Metadata{} = metadata, [_key | keys], json), do: parse(metadata, keys, json)

  defp get_field(nil, _key), do: nil
  defp get_field(stream, key), do: Map.get(stream, key)

  defp get_tag(map, tag) do
    tags = get_in(map, ["format", "tags"])

    tags =
      if is_nil(tags) do
        map
        |> Map.get("streams", [])
        |> Enum.map(&Map.get(&1, "tags"))
        |> Enum.reject(&is_nil/1)
        |> List.first()
      else
        tags
      end

    if tags do
      tags
      |> Enum.find(fn {k, _v} ->
        String.downcase(k) == String.downcase(tag)
      end)
      |> case do
        {_k, v} -> v
        _ -> nil
      end
    end
  end
end
