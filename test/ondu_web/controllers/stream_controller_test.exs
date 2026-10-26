defmodule OnduWeb.StreamControllerTest do
  use OnduWeb.ConnCase, async: false

  alias Ondu.Tracks.Track
  alias Ondu.Transcoder

  setup do
    track = Repo.all(Track.preloaded()) |> Enum.random()

    fixture_path =
      Path.expand("../../support/fixtures/music_files", __DIR__)
      |> Path.join("with_tags/sample.id3v24.mp3")

    file = update_record(track.file, %{path: fixture_path})
    track = %{track | file: file}
    [track: track]
  end

  # Pretends to be ffmpeg, the shell script runs with the input path as $1.
  defp stub_transcode(script) do
    stub(Ondu.Tool.ProbeMock, :exec, fn _path -> {:error, :probe_failed} end)

    stub(Ondu.Tool.TranscodeMock, :exec, fn args ->
      "file://" <> input = Enum.at(args, Enum.find_index(args, &(&1 == "-i")) + 1)

      port =
        Port.open({:spawn_executable, System.find_executable("sh")}, [
          :binary,
          :exit_status,
          args: ["-c", script, "sh", input]
        ])

      {:ok, port}
    end)
  end

  describe "stream with current_user" do
    setup :register_and_log_in_user

    test "returns stream with logged in user", %{conn: conn, track: track} do
      assert get(conn, ~p"/stream/#{track}") |> response(:ok)
    end
  end

  describe "stream ranges" do
    setup :register_and_log_in_user

    setup %{track: track} do
      contents = File.read!(track.file.path)
      file = update_record(track.file, %{size: byte_size(contents)})
      [track: %{track | file: file}, contents: contents, size: byte_size(contents)]
    end

    defp get_range(conn, track, range) do
      conn |> put_req_header("range", range) |> get(~p"/stream/#{track}")
    end

    test "returns the requested bytes", %{conn: conn, track: track, contents: contents} do
      conn = get_range(conn, track, "bytes=10-19")

      assert response(conn, 206) == binary_part(contents, 10, 10)
      assert get_resp_header(conn, "content-range") == ["bytes 10-19/#{byte_size(contents)}"]
    end

    test "returns everything from the start byte", %{conn: conn, track: track} = ctx do
      %{contents: contents, size: size} = ctx
      conn = get_range(conn, track, "bytes=100-")

      assert response(conn, 206) == binary_part(contents, 100, size - 100)
      assert get_resp_header(conn, "content-length") == ["#{size - 100}"]
    end

    test "ends ranges at the end of the file", %{conn: conn, track: track, size: size} do
      conn = get_range(conn, track, "bytes=#{size - 5}-#{size + 100}")

      assert byte_size(response(conn, 206)) == 5
      assert get_resp_header(conn, "content-range") == ["bytes #{size - 5}-#{size - 1}/#{size}"]
    end

    test "refuses ranges starting beyond the file", %{conn: conn, track: track, size: size} do
      conn = get_range(conn, track, "bytes=#{size}-")

      assert response(conn, 416)
      assert get_resp_header(conn, "content-range") == ["bytes */#{size}"]
    end

    test "ignores invalid ranges", %{conn: conn, track: track, contents: contents} do
      assert get_range(conn, track, "bytes=20-10") |> response(200) == contents
    end
  end

  describe "transcode" do
    setup :register_and_log_in_user
    setup :set_mox_global

    setup %{track: track} do
      File.rm_rf!("./tmp/test/transcode")
      start_supervised!(Transcoder)
      stub_transcode(~s(cat "$1"))
      preset = Transcoder.Preset.get(:default_ogg)
      contents = File.read!(track.file.path)
      size = Transcoder.Preset.predicted_size(track.file, preset)
      assert byte_size(contents) < size
      [preset: preset, contents: contents, size: size]
    end

    defp get_transcode(conn, track, headers \\ []) do
      conn = Enum.reduce(headers, conn, fn {k, v}, conn -> put_req_header(conn, k, v) end)
      get(conn, ~p"/stream/#{track}?transcode=1&preset=default_ogg")
    end

    test "has a content length before the transcode is done", %{conn: conn, track: track} = ctx do
      conn = get_transcode(conn, track)

      assert response(conn, 200)
      assert get_resp_header(conn, "content-length") == ["#{ctx.size}"]
      assert get_resp_header(conn, "content-type") == ["audio/ogg"]
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert byte_size(conn.resp_body) == ctx.size
      assert binary_part(conn.resp_body, 0, byte_size(ctx.contents)) == ctx.contents
    end

    test "serves ranges", %{conn: conn, track: track} = ctx do
      conn = get_transcode(conn, track, [{"range", "bytes=10-20"}])

      assert response(conn, 206) == binary_part(ctx.contents, 10, 11)
      assert get_resp_header(conn, "content-range") == ["bytes 10-20/#{ctx.size}"]
      assert get_resp_header(conn, "content-length") == ["11"]
    end

    test "serves open ended ranges to the end", %{conn: conn, track: track} = ctx do
      chunk_size = Transcoder.Utils.chunk_size()
      conn = get_transcode(conn, track, [{"range", "bytes=#{chunk_size - 5}-"}])

      assert get_resp_header(conn, "content-range") == [
               "bytes #{chunk_size - 5}-#{ctx.size - 1}/#{ctx.size}"
             ]

      assert byte_size(response(conn, 206)) == ctx.size - chunk_size + 5
    end

    test "serves ranges across chunk boundaries exactly", %{conn: conn, track: track} = ctx do
      chunk_size = Transcoder.Utils.chunk_size()
      conn = get_transcode(conn, track, [{"range", "bytes=0-#{chunk_size}"}])

      assert byte_size(response(conn, 206)) == chunk_size + 1
      assert binary_part(conn.resp_body, 0, byte_size(ctx.contents)) == ctx.contents
    end

    test "refuses ranges beyond the size", %{conn: conn, track: track} = ctx do
      conn = get_transcode(conn, track, [{"range", "bytes=#{ctx.size}-"}])

      assert response(conn, 416)
      assert get_resp_header(conn, "content-range") == ["bytes */#{ctx.size}"]
    end

    test "downloads have a content length right away", %{conn: conn, track: track} = ctx do
      conn = get(conn, ~p"/download/#{track}?transcode=1&preset=default_ogg")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-length") == ["#{ctx.size}"]
    end

    test "returns busy when too many transcodes are running", %{conn: conn, track: track} do
      stop_supervised!(Transcoder)
      start_supervised!({Transcoder, max_concurrency: 0, max_queue_size: 0})

      conn = get_transcode(conn, track)

      assert response(conn, 503)
    end
  end

  describe "stream with playtoken" do
    setup %{conn: conn} do
      user = Ondu.Accounts.get_user_by_username("testuser")

      conn = %{
        conn
        | secret_key_base: OnduWeb.Endpoint.config(:secret_key_base),
          assigns: %{current_user: user}
      }

      token = OnduWeb.PlayToken.create(conn)
      [token: token]
    end

    test "returns stream with valid token", %{conn: conn, track: track, token: token} do
      assert get(conn, ~p"/stream/#{track}?token=#{token}") |> response(:ok)
    end
  end

  describe "forbidden when not authenticated" do
    test "forbidden when no playtoken or current_user", %{conn: conn, track: track} do
      assert_raise OnduWeb.ForbiddenError, fn ->
        get(conn, ~p"/stream/#{track}")
      end
    end
  end
end
