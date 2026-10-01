defmodule MusicBoxWeb.ArtistArtworkControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Artists.Artist

  setup :register_and_log_in_user

  setup do
    File.rm_rf!(MusicBox.Config.artwork_path())
    dir = Path.absname("./tmp/test/artist_artwork_upload")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    artist = Artist |> Ecto.Query.first() |> Repo.one!()
    [artist: artist, dir: dir]
  end

  defp upload(dir, size) do
    path = Path.join(dir, "#{size}.png")

    # rgb24, older ffmpeg (6.x) rounds odd sizes down otherwise.
    {_, 0} =
      System.cmd(
        "ffmpeg",
        ~w(-y -f lavfi -i color=c=red:s=#{size},format=rgb24 -frames:v 1 #{path}),
        stderr_to_stdout: true
      )

    %Plug.Upload{path: path, filename: "photo.png", content_type: "image/png"}
  end

  test "uploads, replaces and deletes artwork", %{conn: conn, artist: artist, dir: dir} do
    path = ~p"/api/artists/#{artist.id}/artwork"

    assert %{"artwork" => [%{"width" => 128, "height" => 128}, _large]} =
             conn |> put(path, %{file: upload(dir, "300x300")}) |> api_response(200, "Artist")

    assert %{"artwork" => [%{"width" => 256, "height" => 128}, _large]} =
             conn |> put(path, %{file: upload(dir, "400x200")}) |> api_response(200, "Artist")

    assert %{"artwork" => []} = conn |> delete(path) |> api_response(200, "Artist")
  end

  @tag capture_log: true
  test "refuses uploads that are not images", %{conn: conn, artist: artist, dir: dir} do
    path = ~p"/api/artists/#{artist.id}/artwork"
    not_an_image = Path.join(dir, "notes.txt")
    File.write!(not_an_image, "not an image")
    file = %Plug.Upload{path: not_an_image, filename: "notes.txt", content_type: "text/plain"}

    assert %{"error" => "invalid_image"} =
             conn |> put(path, %{file: file}) |> api_response(422, "Error")

    assert %{"error" => "invalid_image"} =
             conn |> put(path, %{file: "not a file"}) |> api_response(422, "Error")

    assert %{"artwork" => []} = conn |> get(~p"/api/artists/#{artist.id}") |> json_response(200)
  end

  # Plug limits multipart bodies to 8MB by default, artwork can be up to 25MB.
  @tag capture_log: true
  test "accepts multipart bodies larger than 8MB", %{conn: conn, artist: artist} do
    boundary = "artwork-boundary"

    body =
      "--#{boundary}\r\n" <>
        ~s(Content-Disposition: form-data; name="file"; filename="large.jpg"\r\n) <>
        "Content-Type: image/jpeg\r\n\r\n" <>
        :binary.copy(<<0>>, 10_000_000) <> "\r\n--#{boundary}--\r\n"

    assert %{"error" => "invalid_image"} =
             conn
             |> put_req_header("content-type", "multipart/form-data; boundary=#{boundary}")
             |> put(~p"/api/artists/#{artist.id}/artwork", body)
             |> api_response(422, "Error")
  end

  test "returns not found for unknown artists", %{conn: conn, dir: dir} do
    assert_error_sent 404, fn ->
      put(conn, ~p"/api/artists/#{Ecto.UUID.generate()}/artwork", %{
        file: upload(dir, "300x300")
      })
    end
  end
end
