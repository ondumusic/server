defmodule MusicBoxWeb.ArtistArtworkController do
  use MusicBoxWeb, :controller

  alias MusicBox.Artists
  alias MusicBox.Artwork
  alias MusicBoxWeb.LibraryJSON

  operation :update,
    summary: "Upload artwork for an artist",
    description: """
    Adds or replaces the artwork for the artist. Images keep their aspect ratio
    (the shortest side of each variant matches its size), so clients can crop
    them however they show artists. Images can be at most 25MB and 10000 pixels.
    """,
    tags: ["Artists"],
    parameters: [
      artist_id: [in: :path, type: Schemas.ArtistId, required: true]
    ],
    request_body:
      {"The image", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{file: %OpenApiSpex.Schema{type: :string, format: :binary}},
         required: [:file]
       }},
    responses: [
      ok: {"The artist with its new artwork.", "application/json", Schemas.Artist},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Artist not found.", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Not an image (invalid_image), or too large (too_large).", "application/json",
         Schemas.Error}
    ]

  def update(conn, %{"artist_id" => artist_id} = params) do
    artist = Artists.get_artist!(artist_id)

    with %Plug.Upload{path: path} <- params["file"],
         {:ok, _artwork} <- Artwork.put(:artists, artist, path) do
      render_artist(conn, artist_id)
    else
      {:error, reason} -> render_error(conn, reason)
      _no_upload -> render_error(conn, :invalid_image)
    end
  end

  operation :delete,
    summary: "Removes the artwork from an artist",
    tags: ["Artists"],
    parameters: [
      artist_id: [in: :path, type: Schemas.ArtistId, required: true]
    ],
    responses: [
      ok: {"The artist without artwork.", "application/json", Schemas.Artist},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Artist not found.", "application/json", Schemas.Error}
    ]

  def delete(conn, %{"artist_id" => artist_id}) do
    :ok = Artwork.delete(:artists, Artists.get_artist!(artist_id))
    render_artist(conn, artist_id)
  end

  defp render_error(conn, reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: to_string(reason)})
  end

  defp render_artist(conn, artist_id) do
    conn
    |> put_view(LibraryJSON)
    |> render(:artist, artist: Artists.get_artist!(artist_id))
  end
end
