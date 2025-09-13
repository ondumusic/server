defmodule MusicBoxWeb.ArtworkController do
  use MusicBoxWeb, :controller

  def show(conn, %{"filename" => filename}) do
    artwork_path =
      Application.get_env(:music_box, MusicBox.Transcoder) |> Keyword.fetch!(:artwork_path)

    file_path = Path.join(artwork_path, filename)

    conn
    |> send_download({:file, file_path},
      disposition: :inline,
      charset: nil,
      encode: false,
      filename: filename,
      content_type: "image/jpeg"
    )
  end
end
