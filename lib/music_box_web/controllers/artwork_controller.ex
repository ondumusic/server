defmodule MusicBoxWeb.ArtworkController do
  use MusicBoxWeb, :controller

  operation :show, false

  @filenames Map.new(MusicBox.Artwork.variants(), fn {variant, _size} ->
               {"#{variant}.jpg", variant}
             end)

  def show(conn, %{"album_id" => album_id, "hash" => hash, "filename" => filename}) do
    with {:ok, album_id} <- Ecto.UUID.cast(album_id),
         {:ok, variant} <- Map.fetch(@filenames, filename),
         file_path = MusicBox.Artwork.variant_path(album_id, variant),
         true <- File.regular?(file_path) do
      conn
      |> put_cache_control(hash)
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

  defp put_cache_control(conn, "0"), do: conn

  defp put_cache_control(conn, _hash) do
    put_resp_header(conn, "cache-control", "public, max-age=31536000, immutable")
  end
end
