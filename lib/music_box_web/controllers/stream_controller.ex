# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBox.Tracks
  alias MusicBox.Transcoder
  alias MusicBox.Transcoder.{Preset, Utils}

  plug :assign_track
  plug :assign_preset

  def transcode(conn, _params) do
    %{track: track, preset: preset} = conn.assigns

    require Logger
    Logger.info("Starting transcoder!")

    # By requesting the first chunk the transcoding will start (if needed).
    Task.start(fn ->
      Transcoder.request_chunk(track.file, preset, 0)
    end)

    conn
    |> json(%{ok: true})
  end

  def stream(conn, %{"transcode" => "1"}) do
    meta = Transcoder.get_meta(conn.assigns.track.file, conn.assigns.preset)
    estimated_file_size = Utils.estimate_file_size(conn.assigns.track.file, conn.assigns.preset)
    actual_file_size = meta && meta.file_size

    complete_file_ranges =
      [
        actual_file_size,
        estimated_file_size
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&(&1 - 1))

    conn
    |> get_req_header("range")
    |> Utils.parse_range_header()
    |> case do
      # The client wants the rest, but already has everything.
      {:ok, ^actual_file_size, :infinity} ->
        send_transcode_completed(conn, actual_file_size)

      {:ok, 0, :infinity} ->
        if actual_file_size do
          send_transcoded_chunk(conn, 0, actual_file_size)
        else
          end_byte = Utils.default_range_size() - 1
          send_transcoded_chunk(conn, 0, end_byte)
        end

      {:ok, start_byte, :infinity} ->
        end_byte = start_byte + Utils.default_range_size() - 1
        send_transcoded_chunk(conn, start_byte, end_byte)

      # For some reason browser prefers to request 0-$filesize instead of just
      # not using a ranged request. So we will treat that scenario as a client
      # that just wants to receive the entire file, as it might be using the
      # estimated file size which is often too small or too big.
      {:ok, 0, file_size} ->
        if file_size in complete_file_ranges do
          send_transcoded_file(conn)
        else
          send_transcoded_chunk(conn, 0, file_size)
        end

      # Alright this client actually wants a small chunk
      {:ok, start_byte, end_byte} ->
        send_transcoded_chunk(conn, start_byte, end_byte)

      # No range? No problem! Send the entire file!
      {:error, :no_range} ->
        send_transcoded_file(conn)

      {:error, :invalid_range} ->
        file_size = actual_file_size || estimated_file_size

        conn
        |> put_status(416)
        |> put_resp_header("content-range", "bytes */#{file_size}")
        |> text("Range Not Satisfiable")
    end
    |> halt()
  end

  def stream(conn, _params) do
    file = conn.assigns.track.file
    content_type = MusicBox.Files.File.mimetype(file)

    conn
    |> get_req_header("range")
    |> Utils.parse_range_header()
    |> case do
      {:ok, start_byte, end_byte} ->
        end_byte =
          if end_byte == :infinity,
            do: file.size,
            else: end_byte

        length = end_byte - start_byte + 1

        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("content-range", "bytes #{start_byte}-#{end_byte}/#{file.size}")
        |> put_resp_header("content-length", "#{length}")
        |> send_file(206, file.path, start_byte, length)

      _ ->
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("content-length", "#{file.size}")
        |> send_file(200, file.path)
    end
  end

  defp put_stream_headers(conn) do
    duration = conn.assigns.track.duration

    content_type =
      case conn.assigns.preset do
        aac when aac in ~w(mobile_aac default_aac)a -> "audio/aac"
        _ -> "audio/webm"
      end

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-content-duration", Float.to_string(duration))
  end

  defp send_busy(conn) do
    conn
    |> put_status(:service_unavailable)
    |> put_resp_header("retry-after", "5")
    |> text("Range Not Satisfiable")
  end

  defp send_transcoded_file(conn) do
    conn
    |> put_stream_headers()
    |> send_chunked(200)
    |> transcode_file()
  end

  defp transcode_file(conn, chunk_index \\ 0) do
    with true <-
           Utils.continue_stream?(conn.assigns.track.file, conn.assigns.preset, chunk_index),
         {:ok, chunk_data} <-
           Transcoder.request_chunk(conn.assigns.track.file, conn.assigns.preset, chunk_index),
         {:ok, new_conn} <- chunk(conn, chunk_data) do
      transcode_file(new_conn, chunk_index + 1)
    else
      {:error, :server_busy} -> send_busy(conn)
      _ -> conn
    end
  end

  defp send_transcode_completed(conn, file_size) do
    conn
    |> put_stream_headers()
    |> put_resp_header("content-range", "bytes */#{file_size}")
    |> send_resp(200, <<>>)
  end

  defp send_transcoded_chunk(conn, start_byte, end_byte) do
    meta = Transcoder.get_meta(conn.assigns.track.file, conn.assigns.preset)
    estimated_file_size = Utils.estimate_file_size(conn.assigns.track.file, conn.assigns.preset)
    actual_file_size = meta && meta.file_size
    file_size = actual_file_size || estimated_file_size
    end_byte = min(end_byte, file_size - 1)

    range_header = "bytes #{start_byte}-#{end_byte}/#{file_size}"

    conn
    |> put_stream_headers()
    |> put_resp_header("content-range", range_header)
    |> send_chunked(206)
    |> transcode_range(Range.new(start_byte, end_byte))
  end

  defp transcode_range(conn, %Range{first: start_byte, last: end_byte}) do
    chunk_size = Utils.chunk_size()
    start_chunk = div(start_byte, chunk_size)
    offset = max(0, start_byte - start_chunk * chunk_size)
    transcode_range(conn, start_chunk, offset, end_byte - start_byte)
  end

  defp transcode_range(conn, _chunk_index, _offset, 0) do
    conn
  end

  defp transcode_range(conn, chunk_index, offset, remaining_bytes)
       when is_integer(remaining_bytes) do
    with true <-
           Utils.continue_stream?(conn.assigns.track.file, conn.assigns.preset, chunk_index),
         {:ok, chunk_data} <-
           Transcoder.request_chunk(conn.assigns.track.file, conn.assigns.preset, chunk_index),
         {chunk_part_data, remaining_bytes} <-
           Utils.get_chunk_part(chunk_data, offset, remaining_bytes),
         {:ok, new_conn} <- chunk(conn, chunk_part_data) do
      transcode_range(new_conn, chunk_index + 1, 0, remaining_bytes)
    else
      {:error, :server_busy} -> send_busy(conn)
      _ -> conn
    end
  end

  defp assign_track(conn, _opts) do
    track_id = Map.get(conn.params, "track_id", "")

    if not authenticated?(conn),
      do: raise(MusicBoxWeb.ForbiddenError)

    track = Tracks.get_track!(track_id)

    conn
    |> assign(:track, track)
  end

  defp assign_preset(conn, _opts) do
    preset =
      conn.params
      |> Map.get("preset", Preset.default_id())
      |> Preset.get()

    assign(conn, :preset, preset)
  end

  defp authenticated?(%{assigns: %{current_user: %{id: _id}}}), do: true

  defp authenticated?(%{params: %{"token" => token}} = conn) do
    case MusicBoxWeb.PlayToken.verify(conn, token) do
      {:ok, _play_token} -> true
      _ -> false
    end
  end

  defp authenticated?(_conn), do: false
end
