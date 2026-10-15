defmodule OnduWeb.AnnotationControllerTest do
  use OnduWeb.ConnCase, async: true

  alias Ondu.Artists.Artist

  setup :register_and_log_in_user

  setup do
    [artist: Artist |> Ecto.Query.first() |> Repo.one!()]
  end

  test "writes and lists annotations", %{conn: conn, artist: artist} do
    missing = Ecto.UUID.generate()

    assert %{"ok" => true, "skipped" => [^missing]} =
             conn
             |> put(~p"/api/annotations/musicbrainz/artists", %{
               entries: [
                 %{entityId: artist.id, data: %{mbid: "b10bbbfc-cf9e-42e0-be17-e2c3e1d2600d"}},
                 %{entityId: missing, data: %{mbid: "x"}}
               ]
             })
             |> api_response(200, "PutAnnotationsResponse")

    artist_id = artist.id

    assert %{"entries" => [%{"entityId" => ^artist_id, "data" => %{"mbid" => "b10bbbfc" <> _}}]} =
             conn
             |> get(~p"/api/annotations/musicbrainz/artists")
             |> api_response(200, "AnnotationPage")

    assert %{"entries" => []} =
             conn |> get(~p"/api/annotations/musicbrainz/albums") |> json_response(200)
  end

  test "does not transform data keys (bypass CamelCaseDecoderPlug)", %{conn: conn, artist: artist} do
    path = ~p"/api/annotations/musicbrainz/artists"
    data = %{"trackCount" => 1, "nested" => %{"someKey" => true}, "snake_key" => "x"}
    put(conn, path, %{entries: [%{entityId: artist.id, data: data}]})

    assert %{"entries" => [%{"data" => ^data}]} = conn |> get(path) |> json_response(200)
  end

  test "removes annotations with null data", %{conn: conn, artist: artist} do
    path = ~p"/api/annotations/musicbrainz/artists"
    put(conn, path, %{entries: [%{entityId: artist.id, data: %{mbid: "x"}}]})

    assert %{"skipped" => []} =
             conn
             |> put(path, %{entries: [%{entityId: artist.id, data: nil}]})
             |> json_response(200)

    assert %{"entries" => []} = conn |> get(path) |> json_response(200)
  end

  test "pages with up to 1000 entries", %{conn: conn} do
    assert %{"pageSize" => 500} =
             conn |> get(~p"/api/annotations/musicbrainz/artists") |> json_response(200)

    assert %{"pageSize" => 1000} =
             conn
             |> get(~p"/api/annotations/musicbrainz/artists?pageSize=1000")
             |> json_response(200)
  end

  test "refuses invalid requests", %{conn: conn, artist: artist} do
    entries = [%{entityId: artist.id, data: %{mbid: "x"}}]

    for {path, body, error} <- [
          {~p"/api/annotations/Music Brainz/artists", %{entries: entries}, "invalid_namespace"},
          {~p"/api/annotations/musicbrainz/tracks", %{entries: entries}, "invalid_entity_type"},
          {~p"/api/annotations/musicbrainz/artists", %{entries: [%{entityId: "x", data: %{}}]},
           "invalid_entries"},
          {~p"/api/annotations/musicbrainz/artists", %{}, "invalid_entries"}
        ] do
      assert %{"error" => ^error} = conn |> put(path, body) |> api_response(422, "Error")
    end

    assert %{"error" => "invalid_entity_type"} =
             conn |> get(~p"/api/annotations/musicbrainz/tracks") |> json_response(422)
  end
end
