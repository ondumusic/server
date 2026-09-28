defmodule MusicBoxWeb.ArtworkController do
  use MusicBoxWeb, :controller

  operation :show, false

  @filenames Map.new(MusicBox.Artwork.variants(), fn {variant, _size} ->
               {"#{variant}.jpg", variant}
             end)

  # The hash in the url only busts caches when the artwork changes, the current
  # artwork is always served so it can be cached forever.
  def show(conn, %{"album_id" => album_id, "filename" => filename}) do
    with {:ok, album_id} <- Ecto.UUID.cast(album_id),
         {:ok, variant} <- Map.fetch(@filenames, filename),
         file_path = MusicBox.Artwork.variant_path(album_id, variant),
         true <- File.regular?(file_path) do
      conn
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_download({:file, file_path},
        disposition: :inline,
        charset: nil,
        encode: false,
        filename: filename,
        content_type: "image/jpeg"
      )
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end
end
