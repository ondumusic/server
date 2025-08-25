defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBox.Transcoder
  alias MusicBox.Transcoder.Utils
  alias MusicBox.Tracks

  plug :assign_track when action in [:stream]

  def stream(conn, %{"transcode" => "1"}) do
    case parse_range_header(conn) do
      {:ok, start_byte, end_byte} ->
        conn
        |> put_stream_headers()
        |> send_file_chunk(start_byte, end_byte)

      :no_range ->
        conn
        |> put_stream_headers()
        |> send_complete_file()

      {:error, _reason} ->
        estimated_file_size = Utils.estimate_opus_size(conn.assigns.track.file)

        conn
        |> put_status(416)
        |> put_resp_header("content-range", "bytes */#{estimated_file_size}")
        |> text("Range Not Satisfiable")
    end
  end

  defp put_stream_headers(conn) do
    conn
    |> put_resp_header("content-type", "audio/webm")
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-content-type-options", "nosniff")
  end

  defp send_file_chunk(conn, start_byte, end_byte) do
    estimated_file_size = Utils.estimate_opus_size(conn.assigns.track.file)
    end_byte = min(end_byte, estimated_file_size - 1)
    range_header = "bytes #{start_byte}-#{end_byte}/#{estimated_file_size}"
    content_length = end_byte - start_byte + 1

    conn
    |> put_resp_header("content-range", range_header)
    |> put_resp_header("content-length", to_string(content_length))
    |> send_chunked(206)
    |> transcode(start_byte, end_byte)
  end

  defp send_complete_file(conn) do
    estimated_file_size = Utils.estimate_opus_size(conn.assigns.track.file)

    conn
    |> put_resp_header("content-length", to_string(estimated_file_size))
    |> send_chunked(200)
    |> transcode(0, estimated_file_size - 1)
  end

  defp transcode(conn, start_byte, end_byte) do
    chunk_size = Utils.chunk_size()
    start_chunk = div(start_byte, chunk_size)
    end_chunk = div(end_byte, chunk_size)

    Enum.reduce_while(start_chunk..end_chunk, conn, fn chunk_index, conn ->
      case Transcoder.request_chunk(conn.assigns.track.file, chunk_index) do
        {:ok, chunk_data} ->
          # Calculate which portion of this chunk we actually need
          chunk_start = chunk_index * chunk_size
          chunk_end = min(chunk_start + byte_size(chunk_data) - 1, end_byte)

          # If this chunk contains data within the requested range
          if chunk_end >= start_byte and chunk_start <= end_byte do
            # Calculate byte offsets within this chunk
            byte_start_in_chunk = max(0, start_byte - chunk_start)
            byte_end_in_chunk = min(byte_size(chunk_data) - 1, end_byte - chunk_start)
            bytes_to_send = byte_end_in_chunk - byte_start_in_chunk + 1

            # Get the binary chunk
            chunk_data = binary_part(chunk_data, byte_start_in_chunk, bytes_to_send)

            # Attempt to send to the client
            case chunk(conn, chunk_data) do
              {:ok, new_conn} -> {:cont, new_conn}
              {:error, _reason} -> {:halt, conn}
            end
          else
            {:cont, conn}
          end

        {:error, _reason} ->
          {:halt, conn}
      end
    end)
  end

  defp parse_range_header(conn) do
    case get_req_header(conn, "range") do
      ["bytes=" <> range] ->
        case String.split(range, "-", parts: 2) do
          [start_str, end_str] ->
            with {start_byte, ""} when start_byte >= 0 <- Integer.parse(start_str),
                 {end_byte, ""} when end_byte >= 0 <- Integer.parse(end_str) do
              # end_byte <- parse_end_byte(end_str, start_byte) do
              {:ok, start_byte, end_byte}
            else
              _ -> {:error, :invalid_range}
            end

          _ ->
            {:error, :invalid_range}
        end

      [] ->
        :no_range

      _ ->
        {:error, :invalid_range}
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
