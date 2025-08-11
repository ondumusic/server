defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBox.Tracks

  plug :assign_track when action in [:stream]

  def stream(conn, _params) do
    send_download(conn, {:file, conn.assigns.track.file.path},
      disposition: :inline,
      charset: nil,
      encode: false,
      filename: Path.basename(conn.assigns.track.file.path)
      # content_type: mime
    )
  end

  defp assign_track(conn, _opts) do
    track_id = Map.get(conn.params, "track_id", "")
    track = Tracks.get_track!(track_id)

    conn
    |> assign(:track, track)
  end
end
