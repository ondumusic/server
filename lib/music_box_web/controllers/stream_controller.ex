defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBox.Songs

  plug :assign_song when action in [:stream]

  def stream(conn, _params) do
    send_download(conn, {:file, conn.assigns.song.file.path},
      disposition: :inline,
      charset: nil,
      encode: false,
      filename: Path.basename(conn.assigns.song.file.path)
      # content_type: mime
    )
  end

  defp assign_song(conn, _opts) do
    song_id = Map.get(conn.params, "song_id", "")
    song = Songs.get_song!(song_id)

    conn
    |> assign(:song, song)
  end
end
