defmodule MusicBoxWeb.LibraryController do
  use MusicBoxWeb, :controller

  alias MusicBox.Albums
  alias MusicBox.Artists
  alias MusicBox.Tracks

  plug :assign_artist when action in [:artist, :artist_albums, :artist_album]
  plug :assign_album when action in [:album, :artist_album]
  plug :assign_track when action in [:track]

  operation :artists,
    summary: "List artists",
    tags: ["Artists"],
    parameters: Schemas.Page.params(),
    responses: [
      ok: {"A paginated list of artists.", "application/json", Schemas.ArtistPage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def artists(conn, params) do
    render(conn, :artists, page: Artists.paginate_artists(params))
  end

  operation :artist,
    summary: "Get a specific artist",
    tags: ["Artists"],
    parameters: [
      artist_id: [in: :path, type: Schemas.ArtistId, required: true]
    ],
    responses: [
      ok: {"Returns the requested Artist.", "application/json", Schemas.Artist},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Artist not found.", "application/json", Schemas.Error}
    ]

  def artist(conn, _params) do
    render(conn, :artist, artist: conn.assigns.artist)
  end

  operation :artist_albums,
    summary: "List albums for a specific artist",
    tags: ["Albums"],
    parameters:
      Schemas.Page.params() ++
        [
          artist_id: [in: :path, type: Schemas.ArtistId, required: true]
        ],
    responses: [
      ok:
        {"Returns a paginated list of albums for the given artist.", "application/json",
         Schemas.AlbumPage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Artist not found.", "application/json", Schemas.Error}
    ]

  def artist_albums(conn, params) do
    page = Albums.paginate_albums_for_artist(conn.assigns.artist, params)
    render(conn, :albums, page: page, render_album: false)
  end

  operation :albums,
    summary: "List albums",
    tags: ["Albums"],
    parameters: Schemas.Page.params(),
    responses: [
      ok: {"Returns a paginated list of albums.", "application/json", Schemas.AlbumPage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def albums(conn, params) do
    render(conn, :albums, page: Albums.paginate_albums(params), render_album: false)
  end

  operation :album,
    summary: "Get a specific album",
    tags: ["Albums"],
    parameters: [
      album_id: [in: :path, type: Schemas.AlbumId, required: true]
    ],
    responses: [
      ok: {"Returns the requested `Album`.", "application/json", Schemas.Album},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Album not found", "application/json", Schemas.Error}
    ]

  def album(conn, _params) do
    render(conn, :album, album: conn.assigns.album, render_album: false)
  end

  operation :artist_album,
    summary: "Get a specific album for a specific artist",
    tags: ["Albums"],
    parameters: [
      artist_id: [in: :path, type: Schemas.ArtistId, required: true],
      album_id: [in: :path, type: Schemas.AlbumId, required: true]
    ],
    responses: [
      ok: {"Returns the requested `Album`.", "application/json", Schemas.Album},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Album not found.", "application/json", Schemas.Error}
    ]

  def artist_album(conn, _params) do
    render(conn, :album, album: conn.assigns.album, render_album: false)
  end

  operation :tracks,
    summary: "List tracks",
    description: """
    Lists tracks with optional filtering and pagination.

    ## Random sort and pagination

    When `sort_by=random`, the server uses the provided `random_seed` to
    maintain consistent ordering across paginated requests. This should be a
    non-negative integer.

    For `sort_by=default` (or omitted), `random_seed` is ignored.
    """,
    tags: ["Tracks"],
    parameters:
      Schemas.Page.params() ++
        [
          artist_id: [in: :query, type: Schemas.ArtistId, required: false],
          album_id: [in: :query, type: Schemas.AlbumId, required: false],
          query: [
            in: :query,
            type: :string,
            required: false,
            description: "A search query to filter tracks by."
          ],
          sort_by: [
            in: :query,
            description: """
            Sort order for results.

            - `default`: sort by artist, album, disc, then track number.
            - `random`: randomized order, stable across pages when `random_seed` is reused.
            """,
            schema: %OpenApiSpex.Schema{
              type: :string,
              default: "default",
              enum: ["default", "random"]
            },
            required: false
          ],
          random_seed: [
            in: :query,
            type: :integer,
            required: false,
            description: """
            Seed for randomized sorting. Required when `sort_by=random`.
            """
          ]
        ],
    responses: [
      ok: {"Returns a paginated list of tracks.", "application/json", Schemas.TrackPage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def tracks(conn, params) do
    render(conn, :tracks, page: Tracks.paginate_tracks(params))
  end

  operation :track,
    summary: "Get a specific track",
    tags: ["Tracks"],
    parameters: [
      track_id: [in: :path, type: Schemas.TrackId, required: true]
    ],
    responses: [
      ok: {"Returns the requested track.", "application/json", Schemas.Track},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Track not found", "application/json", Schemas.Error}
    ]

  def track(conn, _params) do
    render(conn, :track, track: conn.assigns.track, album: conn.assigns.track.album)
  end

  defp assign_artist(conn, _opts) do
    artist_id = Map.get(conn.params, "artist_id", "")
    artist = Artists.get_artist!(artist_id)

    conn
    |> assign(:artist, artist)
  end

  defp assign_album(conn, _opts) do
    album_id = Map.get(conn.params, "album_id", "")

    album =
      if artist = conn.assigns[:artist],
        do: Albums.get_album_for_artist!(artist, album_id),
        else: Albums.get_album!(album_id)

    conn
    |> assign(:album, album)
  end

  defp assign_track(conn, _opts) do
    track_id = Map.get(conn.params, "track_id", "")
    track = Tracks.get_track!(track_id)

    conn
    |> assign(:track, track)
  end
end
