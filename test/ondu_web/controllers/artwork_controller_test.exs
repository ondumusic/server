defmodule OnduWeb.ArtworkControllerTest do
  use OnduWeb.ConnCase, async: false

  import Ecto.Query

  alias Ondu.Albums
  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Artwork
  alias Ondu.Tracks.Track

  setup :register_and_log_in_user

  setup do
    File.rm_rf!(Ondu.Config.artwork_path())
    album = Repo.get_by!(Album, slug: "with-the-beatles")

    for {variant, _size} <- Artwork.variants() do
      path = Artwork.variant_path(:albums, album.id, variant)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "#{variant} bytes")
    end

    {:ok, _artwork} =
      Albums.update_artwork(album, %{
        hash: "abc123",
        width: 450,
        height: 400,
        fetcher: :embedded,
        last_fetch_attempt: DateTime.utc_now()
      })

    [album: album]
  end

  describe "show" do
    test "serves each artwork variant", %{conn: conn, album: album} do
      conn = get(conn, ~p"/artwork/albums/#{album.id}/abc123/thumbnail.jpg")
      assert response(conn, 200) == "thumbnail bytes"
      assert response_content_type(conn, :jpg)

      assert get(conn, ~p"/artwork/albums/#{album.id}/abc123/large.jpg") |> response(200) ==
               "large bytes"
    end

    test "serves the current artwork for any version", %{conn: conn, album: album} do
      assert get(conn, ~p"/artwork/albums/#{album.id}/old-hash/large.jpg") |> response(200) ==
               "large bytes"
    end

    test "caches versioned artwork forever", %{conn: conn, album: album} do
      conn = get(conn, ~p"/artwork/albums/#{album.id}/abc123/large.jpg")
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    end

    test "returns not found for unknown files", %{conn: conn, album: album} do
      assert get(conn, ~p"/artwork/albums/#{album.id}/abc123/source.jpg") |> response(404)
      assert get(conn, ~p"/artwork/albums/#{album.id}/abc123/..") |> response(404)
      assert get(conn, ~p"/artwork/albums/not-a-uuid/abc123/large.jpg") |> response(404)

      assert get(conn, ~p"/artwork/albums/#{Ecto.UUID.generate()}/abc123/large.jpg")
             |> response(404)
    end
  end

  describe "album" do
    test "lists the artwork variants", %{conn: conn, album: album} do
      assert %{
               "artwork" => [
                 %{"url" => thumbnail_url, "width" => 128, "height" => 128},
                 %{"url" => large_url, "width" => 450, "height" => 450}
               ]
             } =
               conn
               |> get(~p"/api/albums/#{album.id}")
               |> api_response(200, "Album")

      assert thumbnail_url =~ ~r"/artwork/albums/#{album.id}/abc123/thumbnail.jpg$"
      assert large_url =~ ~r"/artwork/albums/#{album.id}/abc123/large.jpg$"
    end

    test "has no artwork before it was resized", %{conn: conn, album: album} do
      Albums.update_artwork(album, %{
        fetcher: :embedded,
        last_fetch_attempt: DateTime.utc_now()
      })

      assert %{"artwork" => []} =
               conn
               |> get(~p"/api/albums/#{album.id}")
               |> api_response(200, "Album")
    end
  end

  describe "artist" do
    setup %{album: album} do
      artist = Repo.get!(Artist, album.artist_id)
      source = Path.absname("./tmp/test/artist_photo.png")

      {_, 0} =
        System.cmd("ffmpeg", ~w(-y -f lavfi -i color=c=red:s=800x500 -frames:v 1 #{source}),
          stderr_to_stdout: true
        )

      {:ok, artwork} = Artwork.put(:artists, artist, source)
      [artist: artist, hash: artwork.hash]
    end

    test "lists the artwork variants of artists", %{conn: conn, artist: artist, hash: hash} do
      assert %{"artwork" => [thumbnail, large]} =
               conn |> get(~p"/api/artists/#{artist.id}") |> api_response(200, "Artist")

      assert %{"width" => 205, "height" => 128, "url" => url} = thumbnail
      assert url =~ ~r"/artwork/artists/#{artist.id}/#{hash}/thumbnail.jpg$"
      assert %{"width" => 800, "height" => 500} = large
    end

    test "includes the artwork of artists in sync and tracks", %{conn: conn, artist: artist} do
      assert %{"artists" => artists} = conn |> get(~p"/api/sync") |> api_response(200)
      assert %{"artwork" => [_, _]} = Enum.find(artists, &(&1["id"] == artist.id))

      track = Repo.one!(from(t in Track, where: t.artist_id == ^artist.id, limit: 1))

      # The album of the track has artwork too.
      assert %{"artist" => %{"artwork" => [_, _]}, "album" => %{"artwork" => [_, _]}} =
               conn |> get(~p"/api/tracks/#{track.id}") |> api_response(200, "Track")
    end

    test "serves the artwork of artists", %{conn: conn, artist: artist, hash: hash} do
      conn = get(conn, ~p"/artwork/artists/#{artist.id}/#{hash}/large.jpg")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["image/jpeg"]
      assert get(conn, ~p"/artwork/playlists/#{artist.id}/#{hash}/large.jpg") |> response(404)
    end
  end
end
