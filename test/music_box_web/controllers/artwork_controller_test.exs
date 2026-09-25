defmodule MusicBoxWeb.ArtworkControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Albums
  alias MusicBox.Albums.Album
  alias MusicBox.Artwork

  setup :register_and_log_in_user

  setup do
    File.rm_rf!(MusicBox.Config.artwork_path())
    album = Repo.get_by!(Album, slug: "with-the-beatles")

    for {variant, _size} <- Artwork.variants() do
      path = Artwork.variant_path(album.id, variant)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "#{variant} bytes")
    end

    {:ok, _artwork} =
      Albums.update_artwork(album, %{
        path: Artwork.artwork_dir(album.id),
        width: 450,
        height: 400,
        fetcher: :embedded,
        last_fetch_attempt: DateTime.utc_now()
      })

    [album: album]
  end

  describe "show" do
    test "serves each artwork variant", %{conn: conn, album: album} do
      conn = get(conn, ~p"/artwork/#{album.id}/thumbnail.jpg")
      assert response(conn, 200) == "thumbnail bytes"
      assert response_content_type(conn, :jpg)

      assert get(conn, ~p"/artwork/#{album.id}/large.jpg") |> response(200) == "large bytes"
    end

    test "returns not found for unknown files", %{conn: conn, album: album} do
      assert get(conn, ~p"/artwork/#{album.id}/source.jpg") |> response(404)
      assert get(conn, ~p"/artwork/#{album.id}/..") |> response(404)
      assert get(conn, ~p"/artwork/not-a-uuid/large.jpg") |> response(404)
      assert get(conn, ~p"/artwork/#{Ecto.UUID.generate()}/large.jpg") |> response(404)
    end
  end

  describe "album" do
    test "lists the artwork variants", %{conn: conn, album: album} do
      assert %{
               "artwork" => [
                 %{"url" => thumbnail_url, "width" => 128, "height" => 128},
                 %{"url" => large_url, "width" => 450, "height" => 450}
               ],
               "artworkUrl" => large_url
             } =
               conn
               |> get(~p"/api/albums/#{album.id}")
               |> api_response(200, "Album")

      assert thumbnail_url =~ ~r"/artwork/#{album.id}/thumbnail.jpg$"
      assert large_url =~ ~r"/artwork/#{album.id}/large.jpg$"
    end

    test "has no artwork before it was resized", %{conn: conn, album: album} do
      Albums.update_artwork(album, %{
        fetcher: :embedded,
        last_fetch_attempt: DateTime.utc_now()
      })

      assert %{"artwork" => [], "artworkUrl" => nil} =
               conn
               |> get(~p"/api/albums/#{album.id}")
               |> api_response(200, "Album")
    end
  end
end
