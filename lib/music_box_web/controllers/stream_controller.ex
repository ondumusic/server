defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBox.Tracks

  plug :assign_track when action in [:stream]

  def stream(conn, _params) do
    content_type =
      case conn.assigns.track.file.type do
        :m4a -> "audio/mp4"
        :mp3 -> "audio/mpeg"
        :opus -> "audio/ogg"
        :ogg -> "audio/ogg"
        :flac -> "audio/flac"
        :wav -> "audio/wav"
      end

    conn
    |> send_download({:file, conn.assigns.track.file.path},
      disposition: :inline,
      charset: nil,
      encode: false,
      filename: Path.basename(conn.assigns.track.file.path),
      content_type: content_type
    )
  end

  defp assign_track(conn, _opts) do
    track_id = Map.get(conn.params, "track_id", "")
    track = Tracks.get_track!(track_id)

    conn
    |> assign(:track, track)
  end
end
