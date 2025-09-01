defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBox.Transcoder
  alias MusicBox.Transcoder.Utils
  alias MusicBox.Tracks

  plug :assign_track when action in [:stream]

  def stream(conn, %{"transcode" => "1"}) do
    meta = Transcoder.get_meta(conn.assigns.track.file)
    estimated_file_size = Utils.estimate_opus_size(conn.assigns.track.file)
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
      # For some reason browser prefers to request 0-$filesize instead of just
      # not using a ranged request. So we will treat that scenario as a client
      # that just wants to receive the entire file.
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
      :no_range ->
        send_transcoded_file(conn)

      {:error, _reason} ->
        file_size = actual_file_size || estimated_file_size

        conn
        |> put_status(416)
        |> put_resp_header("content-range", "bytes */#{file_size}")
        |> text("Range Not Satisfiable")
    end
  end

  def stream(conn, _params) do
    content_type =
      case conn.assigns.track.file.type do
        :m4a -> "audio/mp4"
        :mp3 -> "audio/mpeg"
        :opus -> "audio/ogg"
        :ogg -> "audio/ogg"
        :flac -> "audio/flac"
        :wav -> "audio/wav"
      end

    conn
    |> send_download({:file, conn.assigns.track.file.path},
      disposition: :inline,
      charset: nil,
      encode: false,
      filename: Path.basename(conn.assigns.track.file.path),
      content_type: content_type
    )
  end

  defp put_stream_headers(conn) do
    duration = conn.assigns.track.duration

    conn
    |> put_resp_header("content-type", "audio/webm")
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-content-duration", Float.to_string(duration))
  end

  defp send_transcoded_file(conn) do
    conn
    |> put_stream_headers()
    |> send_chunked(200)
    |> transcode_file()
  end

  defp transcode_file(conn, chunk_index \\ 0) do
    with true <- Utils.continue_stream?(conn.assigns.track.file, chunk_index),
         {:ok, chunk_data} <- Transcoder.request_chunk(conn.assigns.track.file, chunk_index),
         {:ok, new_conn} <- chunk(conn, chunk_data) do
      transcode_file(new_conn, chunk_index + 1)
    else
      _ -> conn
    end
  end

  defp send_transcoded_chunk(conn, start_byte, end_byte) do
    meta = Transcoder.get_meta(conn.assigns.track.file)
    estimated_file_size = Utils.estimate_opus_size(conn.assigns.track.file)
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

  defp transcode_range(conn, _chunk_index, _offset, 0), do: conn

  defp transcode_range(conn, chunk_index, offset, remaining_bytes)
       when is_integer(remaining_bytes) do
    with true <- Utils.continue_stream?(conn.assigns.track.file, chunk_index),
         {:ok, chunk_data} <- Transcoder.request_chunk(conn.assigns.track.file, chunk_index),
         {chunk_part_data, remaining_bytes} <-
           Utils.get_chunk_part(chunk_data, offset, remaining_bytes),
         {:ok, new_conn} <- chunk(conn, chunk_part_data) do
      transcode_range(new_conn, chunk_index + 1, 0, remaining_bytes)
    else
      _ -> conn
    end
  end

  defp assign_track(conn, _opts) do
    with track_id = Map.get(conn.params, "track_id", ""),
         token = Map.get(conn.params, "token", ""),
         {:ok, _play_token} <- MusicBoxWeb.PlayToken.verify(conn, token) do
      track = Tracks.get_track!(track_id)

      conn
      |> assign(:track, track)
    else
      _ -> raise MusicBoxWeb.ForbiddenError
    end
  end
end
