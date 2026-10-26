defmodule OnduWeb.StreamController do
  use OnduWeb, :controller

  alias Ondu.Storage
  alias Ondu.Tracks
  alias Ondu.Transcoder
  alias Ondu.Transcoder.{Preset, Utils}

  plug :require_authentication
  plug :assign_track
  plug :assign_preset

  operation :download,
    summary: "Download a specific track",
    tags: ["Tracks"],
    security: [%{"sessionToken" => []}, %{"playToken" => []}],
    parameters: [
      track_id: [in: :path, type: Schemas.TrackId, required: true],
      transcode: [
        in: :query,
        description: "Enable live transcoding for this track.",
        schema: %OpenApiSpex.Schema{type: :string, enum: ["1", "0"], default: "0"},
        required: false,
        example: "1"
      ],
      preset: [
        in: :query,
        description: "Which transcoding preset to use.",
        schema: %OpenApiSpex.Schema{
          type: :string,
          enum: Preset.ids(),
          default: "default_ogg"
        },
        required: false,
        example: "default_ogg"
      ],
      range: [
        in: :header,
        description:
          "Byte range to return, e.g. `bytes=0-1023` for the first 1024 bytes, or `bytes=1024-` for everything from byte 1024 onward. When present, the server responds with 206 Partial Content instead of 200.",
        required: false,
        example: "bytes=0-1023"
      ]
    ],
    responses: [
      ok: %OpenApiSpex.Response{
        description: "Returns the file contents for the given track.",
        content: %{
          "application/octet-stream" => %OpenApiSpex.MediaType{
            schema: %OpenApiSpex.Schema{
              type: :string,
              format: :binary
            }
          }
        },
        headers: %{
          "content-type" => %OpenApiSpex.Header{
            description: "The actual MIME type of the file (e.g. audio/mp3)",
            schema: %OpenApiSpex.Schema{type: :string}
          }
        }
      },
      partial_content: %OpenApiSpex.Response{
        description:
          "Returns partial file contents of the given track according to the Range request.",
        content: %{
          "application/octet-stream" => %OpenApiSpex.MediaType{
            schema: %OpenApiSpex.Schema{
              type: :string,
              format: :binary
            }
          }
        },
        headers: %{
          "content-type" => %OpenApiSpex.Header{
            description: "The actual MIME type of the file (e.g. audio/mp3)",
            schema: %OpenApiSpex.Schema{type: :string}
          }
        }
      },
      bad_request: {"Unknown preset.", "application/json", Schemas.Error},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Track not found.", "application/json", Schemas.Error},
      requested_range_not_satisfiable:
        {"The requested range starts beyond the end of the file.", "text/plain",
         %OpenApiSpex.Schema{type: :string}}
    ]

  def download(conn, %{"transcode" => "1"}) do
    %{track: track, preset: preset} = conn.assigns
    size = Utils.known_file_size(track.file, preset)
    send_sized_transcode(conn, :ok, track, preset, 0, size - 1)
  end

  def download(conn, params), do: stream(conn, params)

  operation :stream,
    summary: "Stream a specific track",
    tags: ["Tracks"],
    security: [%{"sessionToken" => []}, %{"playToken" => []}],
    parameters: [
      track_id: [in: :path, type: Schemas.TrackId, required: true],
      transcode: [
        in: :query,
        description: "Enable live transcoding for this track.",
        schema: %OpenApiSpex.Schema{type: :string, enum: ["1", "0"], default: "0"},
        required: false,
        example: "1"
      ],
      preset: [
        in: :query,
        description: "Which transcoding preset to use.",
        schema: %OpenApiSpex.Schema{
          type: :string,
          enum: Preset.ids(),
          default: "default_ogg"
        },
        required: false,
        example: "default_ogg"
      ],
      range: [
        in: :header,
        description:
          "Byte range to return, e.g. `bytes=0-1023` for the first 1024 bytes, or `bytes=1024-` for everything from byte 1024 onward. When present, the server responds with 206 Partial Content instead of 200.",
        required: false,
        example: "bytes=0-1023"
      ]
    ],
    responses: [
      ok: %OpenApiSpex.Response{
        description: "Returns the file contents for the given track.",
        content: %{
          "application/octet-stream" => %OpenApiSpex.MediaType{
            schema: %OpenApiSpex.Schema{
              type: :string,
              format: :binary
            }
          }
        },
        headers: %{
          "content-type" => %OpenApiSpex.Header{
            description: "The actual MIME type of the file (e.g. audio/mp3)",
            schema: %OpenApiSpex.Schema{type: :string}
          }
        }
      },
      partial_content: %OpenApiSpex.Response{
        description:
          "Returns partial file contents of the given track according to the Range request.",
        content: %{
          "application/octet-stream" => %OpenApiSpex.MediaType{
            schema: %OpenApiSpex.Schema{
              type: :string,
              format: :binary
            }
          }
        },
        headers: %{
          "content-type" => %OpenApiSpex.Header{
            description: "The actual MIME type of the file (e.g. audio/mp3)",
            schema: %OpenApiSpex.Schema{type: :string}
          }
        }
      },
      bad_request: {"Unknown preset.", "application/json", Schemas.Error},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Track not found.", "application/json", Schemas.Error},
      requested_range_not_satisfiable:
        {"The requested range starts beyond the end of the file.", "text/plain",
         %OpenApiSpex.Schema{type: :string}}
    ]

  def stream(conn, %{"transcode" => "1"}) do
    %{track: track, preset: preset} = conn.assigns

    conn
    |> serve_sized_transcode(parse_range(conn), track, preset)
    |> halt()
  end

  def stream(conn, _params) do
    %{track: %{file: file}} = conn.assigns
    content_type = Ondu.Files.File.mimetype(file)

    case conn |> parse_range() |> fit_range(file.size) do
      {:ok, start_byte, end_byte} ->
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("content-range", "bytes #{start_byte}-#{end_byte}/#{file.size}")
        |> put_resp_header("content-length", "#{end_byte - start_byte + 1}")
        |> send_chunked(:partial_content)
        |> stream_data(Storage.stream!(file.path, start_byte..end_byte))

      {:error, :unsatisfiable_range} ->
        conn
        |> put_status(416)
        |> put_resp_header("content-range", "bytes */#{file.size}")
        |> text("Range Not Satisfiable")

      _ ->
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("content-length", "#{file.size}")
        |> send_chunked(:ok)
        |> stream_data(Storage.stream!(file.path))
    end
  end

  # A transcode is served like a regular file: its size is known before it is
  # done, so ranges are honest and a request for bytes that are not transcoded
  # yet simply waits for them.
  defp serve_sized_transcode(conn, range, track, preset) do
    file = track.file
    size = Utils.known_file_size(file, preset)

    case fit_range(range, size) do
      {:ok, start_byte, end_byte} ->
        conn
        |> put_resp_header("content-range", "bytes #{start_byte}-#{end_byte}/#{size}")
        |> send_sized_transcode(:partial_content, track, preset, start_byte, end_byte)

      {:error, :unsatisfiable_range} ->
        conn
        |> put_status(416)
        |> put_resp_header("content-range", "bytes */#{size}")
        |> text("Range Not Satisfiable")

      _ ->
        send_sized_transcode(conn, :ok, track, preset, 0, size - 1)
    end
  end

  # The first chunk is requested before the headers are sent, so a full queue
  # can still be answered with a busy response (and it starts the transcode).
  defp send_sized_transcode(conn, status, track, preset, start_byte, end_byte) do
    file = track.file
    first_chunk = div(start_byte, Utils.chunk_size())

    case Transcoder.request_chunk(file, preset, first_chunk) do
      {:ok, _data} ->
        conn
        |> put_stream_headers(track, preset)
        |> put_resp_header("content-length", "#{end_byte - start_byte + 1}")
        |> send_chunked(status)
        |> stream_transcoded_range(file, preset, start_byte, end_byte)

      {:error, :server_busy} ->
        send_busy(conn)

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> text("Transcoding failed")
    end
  end

  defp parse_range(conn) do
    conn
    |> get_req_header("range")
    |> Utils.parse_range_header()
  end

  # Ranges can end beyond the file (e.g. "bytes=0-" is the whole file) but have to
  # start within it. Ranges that end before they start are invalid and ignored.
  defp fit_range({:ok, start_byte, _end_byte}, size) when start_byte >= size,
    do: {:error, :unsatisfiable_range}

  defp fit_range({:ok, start_byte, end_byte}, size) do
    end_byte = if end_byte == :infinity, do: size - 1, else: min(end_byte, size - 1)
    if start_byte <= end_byte, do: {:ok, start_byte, end_byte}, else: {:error, :invalid_range}
  end

  defp fit_range(range, _size), do: range

  defp stream_transcoded_range(conn, file, preset, start_byte, end_byte) do
    chunk_size = Utils.chunk_size()
    first_chunk = div(start_byte, chunk_size)
    last_chunk = div(end_byte, chunk_size)

    Enum.reduce_while(first_chunk..last_chunk//1, conn, fn chunk_index, conn ->
      with true <- Utils.continue_stream?(file, preset, chunk_index),
           {:ok, data} <- Transcoder.request_chunk(file, preset, chunk_index),
           part = Utils.slice_chunk(data, chunk_index, start_byte, end_byte),
           {:ok, conn} <- chunk(conn, part) do
        {:cont, conn}
      else
        {:error, :server_busy} when chunk_index == first_chunk -> {:halt, send_busy(conn)}
        _ -> {:halt, conn}
      end
    end)
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
      raise OnduWeb.ForbiddenError
    end
  end

  defp authenticated?(%{assigns: %{current_user: %{id: _}}}), do: true

  defp authenticated?(%{params: %{"token" => token}} = conn) do
    match?({:ok, _}, OnduWeb.PlayToken.verify(conn, token))
  end

  defp authenticated?(_conn), do: false

  defp assign_track(conn, _opts) do
    track = Tracks.get_track!(conn.params["track_id"])
    assign(conn, :track, track)
  end

  # A preset the server does not have is refused rather than swapped for the
  # default: a client that asks for one by name expects that format.
  defp assign_preset(conn, _opts) do
    case Map.fetch(conn.params, "preset") do
      :error ->
        assign(conn, :preset, Preset.default_preset())

      {:ok, id} ->
        case Preset.get(id) do
          %Preset{} = preset ->
            assign(conn, :preset, preset)

          nil ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Unknown preset"})
            |> halt()
        end
    end
  end
end
