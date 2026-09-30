defmodule MusicBoxWeb.PlayController do
  use MusicBoxWeb, :controller

  alias MusicBox.Plays

  operation :record_plays,
    summary: "Record plays",
    description: """

    We recommend only counting plays for tracks that were played at least half
    of its duration (with a cap of 4 minutes for very long tracks) and generally
    discourage counting tracks that with a duration of 30s or less.

    It will ignore plays that have been submitted before (based on the idempotent
    client generated id) or for tracks that don't exist.
    """,
    tags: ["Tracks"],
    request_body: {"Plays", "application/json", Schemas.RecordPlaysRequest},
    responses: [
      ok: {"The plays were stored.", "application/json", Schemas.RecordPlaysResponse},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      unprocessable_entity: {"Invalid plays, or too many.", "application/json", Schemas.Error}
    ]

  def record_plays(conn, params) do
    case Plays.record(Map.get(params, "plays")) do
      :ok ->
        json(conn, %{ok: true})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end
end
