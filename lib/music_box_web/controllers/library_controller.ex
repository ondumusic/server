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
      ok: {"Artists", "application/json", Schemas.ArtistPage},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
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
      ok: {"Artist", "application/json", Schemas.Artist},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
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
      ok: {"Albums", "application/json", Schemas.AlbumPage},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]

  def artist_albums(conn, params) do
    page = Albums.paginate_albums_for_artist(conn.assigns.artist, params)
    render(conn, :albums, page: page)
  end

  operation :albums,
    summary: "List albums",
    tags: ["Albums"],
    parameters: Schemas.Page.params(),
    responses: [
      ok: {"Album", "application/json", Schemas.AlbumPage},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def albums(conn, params) do
    render(conn, :albums, page: Albums.paginate_albums(params))
  end

  operation :album,
    summary: "Get a specific album",
    tags: ["Albums"],
    parameters: [
      album_id: [in: :path, type: Schemas.AlbumId, required: true]
    ],
    responses: [
      ok: {"Album", "application/json", Schemas.Album},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]

  def album(conn, _params) do
    render(conn, :album, album: conn.assigns.album)
  end

  operation :artist_album,
    summary: "Get a specific album for a specific artist",
    tags: ["Albums"],
    parameters: [
      artist_id: [in: :path, type: Schemas.ArtistId, required: true],
      album_id: [in: :path, type: Schemas.AlbumId, required: true]
    ],
    responses: [
      ok: {"Album", "application/json", Schemas.Album},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]

  def artist_album(conn, _params) do
    render(conn, :album, album: conn.assigns.album)
  end

  operation :tracks,
    summary: "List tracks",
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
          random_seed: [
            in: :query,
            type: :integer,
            required: false,
            description: "To ensure consistent pagination when using random sort."
          ],
          sort_by: [
            in: :query,
            description: "Maintain default sorting (artist,album,disc,number) or random",
            schema: %OpenApiSpex.Schema{
              type: :string,
              default: "default",
              enum: ["default", "random"]
            },
            required: false
          ]
        ],
    responses: [
      ok: {"Tracks", "application/json", Schemas.TrackPage},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
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
      ok: {"Track", "application/json", Schemas.Track},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
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
