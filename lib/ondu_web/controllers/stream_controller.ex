defmodule OnduWeb.StreamController do
  use OnduWeb, :controller

  alias Ondu.Storage
  alias Ondu.Tracks
  alias Ondu.Transcoder
  alias Ondu.Transcoder.{Preset, Utils}

  plug :require_authentication
  plug :assign_track
  plug :assign_preset

  operation :transcode,
    summary: "Transcode a specific track",
    tags: ["Tracks"],
    security: [%{"sessionToken" => []}, %{"playToken" => []}],
    parameters: [
      track_id: [in: :path, type: Schemas.TrackId, required: true],
      async: [
        in: :query,
        description:
          "When set to 1 it will start in background and return a basic JSON confirmation, there is no notification or anything indicating completion.",
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
      ]
    ],
    responses: [
      ok: %OpenApiSpex.Response{
        description: """
        The response will be a `text/event-stream` that waits until transcoding
        is completed, and returns the transcoded filesize. When using `async=1`
        however it will return a basic acknowledgement as `application/json`.
        """,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %OpenApiSpex.Schema{
              type: :object,
              properties: %{
                ok: %OpenApiSpex.Schema{type: :boolean, example: true}
              },
              required: [:ok],
              example: %{ok: true}
            }
          },
          "text/event-stream" => %OpenApiSpex.MediaType{
            schema: %OpenApiSpex.Schema{
              type: :string,
              description: """
              SSE stream which eventually returns the transcoded filesize, or
              an `error` event when transcoding failed.
              """,
              example: "1024"
            }
          }
        }
      },
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Track not found.", "application/json", Schemas.Error},
      internal_server_error: {"Transcoding failed.", "application/json", Schemas.Error},
      service_unavailable:
        {"Too many transcodes, try again later.", "text/plain",
         %OpenApiSpex.Schema{type: :string}}
    ]

  def transcode(conn, %{"async" => "1"}) do
    %{track: %{file: file}, preset: preset} = conn.assigns
    Task.start(fn -> Transcoder.request_chunk(file, preset, 0) end)
    json(conn, %{ok: true})
  end

  def transcode(conn, _params) do
    %{track: %{file: file}, preset: preset} = conn.assigns

    # Waits for the first chunk, so the transcode has started (or completed).
    case Transcoder.request_chunk(file, preset, 0) do
      {:ok, _chunk} ->
        conn
        |> put_resp_content_type("text/event-stream")
        |> send_chunked(:ok)
        |> await_transcode(file, preset)

      {:error, :server_busy} ->
        send_busy(conn)

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Transcoding failed"})
    end
  end

  # Every transcode ends up either completed or failed (ffmpeg has a timeout),
  # failed transcodes are removed after a while so no meta means failed too.
  defp await_transcode(conn, file, preset) do
    case Transcoder.get_meta(file, preset) do
      %{completed_at: completed, file_size: size} when not is_nil(completed) ->
        send_event(conn, "data: #{JSON.encode!(%{size: size})}")

      %{failed_at: nil} ->
        case chunk(conn, ":\n\n") do
          {:ok, conn} ->
            Process.sleep(500)
            await_transcode(conn, file, preset)

          {:error, :closed} ->
            conn
        end

      _failed ->
        send_event(conn, "event: error\ndata: #{JSON.encode!(%{error: "Transcoding failed"})}")
    end
  end

  defp send_event(conn, event) do
    case chunk(conn, event <> "\n\n") do
      {:ok, conn} -> conn
      {:error, :closed} -> conn
    end
  end

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
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Track not found.", "application/json", Schemas.Error},
      requested_range_not_satisfiable:
        {"The requested range starts beyond the end of the file.", "text/plain",
         %OpenApiSpex.Schema{type: :string}}
    ]

  def download(conn, %{"transcode" => "1"}) do
    %{track: %{file: file} = track, preset: preset} = conn.assigns

    case Utils.known_file_size(file, preset) do
      size when is_integer(size) ->
        conn
        |> put_resp_header("content-length", "#{size}")
        |> send_transcoded_file_with_headers(track, preset)

      nil ->
        send_transcoded_file_with_headers(conn, track, preset)
    end
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
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Track not found.", "application/json", Schemas.Error},
      requested_range_not_satisfiable:
        {"The requested range starts beyond the end of the file.", "text/plain",
         %OpenApiSpex.Schema{type: :string}}
    ]

  def stream(conn, %{"transcode" => "1"}) do
    %{track: track, preset: preset} = conn.assigns

    range =
      conn
      |> parse_range()
      |> disable_range_for_adts(preset)

    if preset.exact_size? do
      conn
      |> serve_sized_transcode(range, track, preset)
      |> halt()
    else
      conn
      |> serve_transcoded(range, track, preset)
      |> halt()
    end
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

  # Presets with an exact size are served like a regular file: the size is
  # known before the transcode is done, so ranges are honest and a request for
  # bytes that are not transcoded yet simply waits for them.
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

  # Transcoded range dispatch (presets without an exact size)
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

  # Ranges can end beyond the file (e.g. "bytes=0-" is the whole file) but have to
  # start within it. Ranges that end before they start are invalid and ignored.
  defp fit_range({:ok, start_byte, _end_byte}, size) when start_byte >= size,
    do: {:error, :unsatisfiable_range}

  defp fit_range({:ok, start_byte, end_byte}, size) do
    end_byte = if end_byte == :infinity, do: size - 1, else: min(end_byte, size - 1)
    if start_byte <= end_byte, do: {:ok, start_byte, end_byte}, else: {:error, :invalid_range}
  end

  defp fit_range(range, _size), do: range

  defp disable_range_for_adts(_range, %{ffmpeg_preset: :adts}), do: {:error, :no_range}
  defp disable_range_for_adts(range, _preset), do: range

  defp full_file_range?(file, preset, end_byte) do
    case {actual_file_size(file, preset), estimated_file_size(file, preset)} do
      {actual, _} when is_integer(actual) and end_byte == actual - 1 -> true
      {_, estimated} when is_integer(estimated) and end_byte == estimated - 1 -> true
      _ -> false
    end
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

  defp assign_preset(conn, _opts) do
    preset =
      conn.params
      |> Map.get("preset", "default")
      |> Preset.get()

    assign(conn, :preset, preset)
  end
end
