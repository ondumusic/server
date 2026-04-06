defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBox.Storage
  alias MusicBox.Tracks
  alias MusicBox.Transcoder
  alias MusicBox.Transcoder.{Preset, Utils}

  plug :require_authentication
  plug :assign_track
  plug :assign_preset

  def transcode(conn, %{"async" => "1"}) do
    %{track: %{file: file}, preset: preset} = conn.assigns
    Task.start(fn -> Transcoder.request_chunk(file, preset, 0) end)
    json(conn, %{ok: true})
  end

  def transcode(conn, _params) do
    %{track: %{file: file}, preset: preset} = conn.assigns
    Transcoder.request_chunk(file, preset, 0)

    conn
    |> put_resp_content_type("text/event-stream")
    |> send_chunked(:ok)
    |> await_transcode(file, preset)
  end

  defp await_transcode(conn, file, preset) do
    case Transcoder.get_meta(file, preset) do
      %{completed_at: completed, file_size: size} when not is_nil(completed) ->
        chunk(conn, "data: #{JSON.encode!(%{size: size})}\n\n")
        conn

      _ ->
        chunk(conn, ":\n\n")
        Process.sleep(500)
        await_transcode(conn, file, preset)
    end
  end

  def download(conn, %{"transcode" => "1"}) do
    %{track: %{file: file} = track, preset: preset} = conn.assigns

    case actual_file_size(file, preset) do
      size when is_integer(size) ->
        conn
        |> put_resp_header("content-length", "#{size}")
        |> send_transcoded_file_with_headers(track, preset)

      nil ->
        send_transcoded_file_with_headers(conn, track, preset)
    end
  end

  def download(conn, params), do: stream(conn, params)

  def stream(conn, %{"transcode" => "1"}) do
    %{track: track, preset: preset} = conn.assigns

    range =
      conn
      |> parse_range()
      |> disable_range_for_adts(preset)

    conn
    |> serve_transcoded(range, track, preset)
    |> halt()
  end

  def stream(conn, _params) do
    %{track: %{file: file}} = conn.assigns
    content_type = MusicBox.Files.File.mimetype(file)

    case parse_range(conn) do
      {:ok, start_byte, end_byte} ->
        end_byte = if end_byte == :infinity, do: file.size - 1, else: end_byte
        length = end_byte - start_byte + 1

        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("content-range", "bytes #{start_byte}-#{end_byte}/#{file.size}")
        |> put_resp_header("content-length", "#{length}")
        |> send_chunked(:partial_content)
        |> stream_data(Storage.get_bytes(file.path, start_byte, length))

      _ ->
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("content-length", "#{file.size}")
        |> send_chunked(:ok)
        |> stream_data(Storage.stream!(file.path))
    end
  end

  # Transcoded range dispatch
  # - No range at all -> send entire file
  # - 0 - :infinity -> send entire file (or first default chunk if still transcoding)
  # - N - :infinity -> send a default-sized chunk from offset N
  # - 0 - <full size> -> browsers sometimes request 0-filesize instead of no range, so treat it as "send everything"
  # - N-M -> actual partial range request
  # - Invalid -> 416

  defp serve_transcoded(conn, {:error, :no_range}, track, preset) do
    send_transcoded_file_with_headers(conn, track, preset)
  end

  defp serve_transcoded(conn, {:error, :invalid_range}, track, preset) do
    file = track.file
    file_size = actual_file_size(file, preset) || estimated_file_size(file, preset)

    conn
    |> put_status(416)
    |> put_resp_header("content-range", "bytes */#{file_size}")
    |> text("Range Not Satisfiable")
  end

  defp serve_transcoded(conn, {:ok, 0, :infinity}, track, preset) do
    file = track.file

    case actual_file_size(file, preset) do
      nil -> send_transcoded_chunk(conn, track, preset, 0, Utils.default_range_size() - 1)
      _size -> send_transcoded_file_with_headers(conn, track, preset)
    end
  end

  # Client already has everything
  defp serve_transcoded(conn, {:ok, start_byte, :infinity}, track, preset) do
    file = track.file
    actual = actual_file_size(file, preset)

    if actual && start_byte == actual do
      send_transcode_completed(conn, track, preset, actual)
    else
      end_byte = start_byte + Utils.default_range_size() - 1
      send_transcoded_chunk(conn, track, preset, start_byte, end_byte)
    end
  end

  # Browser quirk: requesting 0-<full file size> instead of omitting range
  defp serve_transcoded(conn, {:ok, 0, end_byte}, track, preset) do
    if full_file_range?(track.file, preset, end_byte) do
      send_transcoded_file_with_headers(conn, track, preset)
    else
      send_transcoded_chunk(conn, track, preset, 0, end_byte)
    end
  end

  defp serve_transcoded(conn, {:ok, start_byte, end_byte}, track, preset) do
    send_transcoded_chunk(conn, track, preset, start_byte, end_byte)
  end

  defp parse_range(conn) do
    conn
    |> get_req_header("range")
    |> Utils.parse_range_header()
  end

  defp disable_range_for_adts(_range, %{ffmpeg_preset: :adts}), do: {:error, :no_range}
  defp disable_range_for_adts(range, _preset), do: range

  defp full_file_range?(file, preset, end_byte) do
    actual = actual_file_size(file, preset)
    estimated = estimated_file_size(file, preset)

    (actual && end_byte == actual - 1) || (estimated && end_byte == estimated - 1)
  end

  defp actual_file_size(file, preset) do
    case Transcoder.get_meta(file, preset) do
      %{file_size: size} when is_integer(size) and size > 0 -> size
      _ -> nil
    end
  end

  defp estimated_file_size(file, preset), do: Utils.estimate_file_size(file, preset)

  defp send_transcoded_file_with_headers(conn, track, preset) do
    conn
    |> put_stream_headers(track, preset)
    |> send_chunked(:ok)
    |> stream_transcoded_chunks(track.file, preset)
  end

  defp send_transcode_completed(conn, track, preset, file_size) do
    conn
    |> put_stream_headers(track, preset)
    |> put_resp_header("content-range", "bytes */#{file_size}")
    |> send_resp(:ok, <<>>)
  end

  defp send_transcoded_chunk(conn, track, preset, start_byte, end_byte) do
    file = track.file
    file_size = actual_file_size(file, preset) || estimated_file_size(file, preset)
    end_byte = min(end_byte, file_size - 1)

    conn
    |> put_stream_headers(track, preset)
    |> put_resp_header("content-range", "bytes #{start_byte}-#{end_byte}/#{file_size}")
    |> send_chunked(:partial_content)
    |> stream_transcoded_range(file, preset, start_byte, end_byte)
  end

  defp stream_transcoded_chunks(conn, file, preset, chunk_index \\ 0) do
    with true <- Utils.continue_stream?(file, preset, chunk_index),
         {:ok, data} <- Transcoder.request_chunk(file, preset, chunk_index),
         {:ok, conn} <- chunk(conn, data) do
      stream_transcoded_chunks(conn, file, preset, chunk_index + 1)
    else
      {:error, :server_busy} when chunk_index == 0 -> send_busy(conn)
      _ -> conn
    end
  end

  defp stream_transcoded_range(conn, file, preset, start_byte, end_byte) do
    chunk_size = Utils.chunk_size()
    start_chunk = div(start_byte, chunk_size)
    offset = max(0, start_byte - start_chunk * chunk_size)
    remaining = end_byte - start_byte

    do_stream_range(conn, file, preset, start_chunk, offset, remaining)
  end

  defp do_stream_range(conn, _file, _preset, _chunk_index, _offset, 0), do: conn

  defp do_stream_range(conn, file, preset, chunk_index, offset, remaining) do
    with true <- Utils.continue_stream?(file, preset, chunk_index),
         {:ok, data} <- Transcoder.request_chunk(file, preset, chunk_index),
         {part, remaining} <- Utils.get_chunk_part(data, offset, remaining),
         {:ok, conn} <- chunk(conn, part) do
      do_stream_range(conn, file, preset, chunk_index + 1, 0, remaining)
    else
      {:error, :server_busy} -> send_busy(conn)
      _ -> conn
    end
  end

  defp stream_data(conn, data) when is_binary(data) or is_list(data) do
    case chunk(conn, data) do
      {:ok, conn} -> conn
      {:error, :closed} -> conn
    end
  end

  defp stream_data(conn, stream) do
    Enum.reduce_while(stream, conn, fn data, conn ->
      case chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end

  defp put_stream_headers(conn, track, preset) do
    conn
    |> put_resp_header("content-type", preset.mimetype)
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-content-duration", Float.to_string(track.duration))
  end

  defp send_busy(conn) do
    conn
    |> put_status(:service_unavailable)
    |> put_resp_header("retry-after", "5")
    |> text("Server Busy")
  end

  defp require_authentication(conn, _opts) do
    if authenticated?(conn) do
      conn
    else
      raise MusicBoxWeb.ForbiddenError
    end
  end

  defp authenticated?(%{assigns: %{current_user: %{id: _}}}), do: true

  defp authenticated?(%{params: %{"token" => token}} = conn) do
    match?({:ok, _}, MusicBoxWeb.PlayToken.verify(conn, token))
  end

  defp authenticated?(_conn), do: false

  defp assign_track(conn, _opts) do
    track = Tracks.get_track!(conn.params["track_id"])
    assign(conn, :track, track)
  end

  defp assign_preset(conn, _opts) do
    preset =
      conn.params
      |> Map.get("preset", "default")
      |> Preset.get()

    assign(conn, :preset, preset)
  end
end
