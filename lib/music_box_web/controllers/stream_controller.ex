defmodule MusicBoxWeb.StreamController do
  use MusicBoxWeb, :controller

  alias MusicBoxWeb.SharedTrack
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
    with track_id = Map.get(conn.params, "track_id", ""),
         token = Map.get(conn.params, "token", ""),
         {:ok, shared_track} <- SharedTrack.verify(conn, token),
         true <- shared_track.track_id == track_id do
      track = Tracks.get_track!(track_id)

      conn
      |> assign(:track, track)
    else
      _ -> raise MusicBoxWeb.ForbiddenError
    end
  end
end
