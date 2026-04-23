defmodule MusicBoxWeb.ArtworkController do
  use MusicBoxWeb, :controller

  operation :show, false

  def show(conn, %{"filename" => filename}) do
    file_path =
      MusicBox.Config.artwork_path()
      |> Path.join(filename)

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
